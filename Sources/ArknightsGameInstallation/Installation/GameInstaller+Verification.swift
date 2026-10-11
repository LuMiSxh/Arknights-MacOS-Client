// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Darwin
import Foundation
import OSLog
import Synchronization

/// Selects the manifest files that must be downloaded. Existing files the previous manifest
/// cannot vouch for are hashed first; that pass is cancellable and reported as progress.
extension GameInstaller {
	struct PendingDownloads: Sendable {
		let files: [ManifestFile]
		/// The last progress sequence emitted, so download progress continues after it.
		let lastSequence: UInt64
	}

	func pendingDownloads(
		in manifest: GameManifest,
		installDirectory: InstallerDirectory,
		previousFiles: [String: ManifestFile]?,
		verifyAllExistingFiles: Bool,
		progress: @escaping ProgressHandler,
		willHash: @escaping @Sendable (String) -> Void = { _ in },
		didRead: @escaping @Sendable (Int) -> Void = { _ in }
	) async throws -> PendingDownloads {
		let checkPass = InstallerSignposts.signposter.beginInterval(
			"Check pass", id: InstallerSignposts.signposter.makeSignpostID())
		defer { InstallerSignposts.signposter.endInterval("Check pass", checkPass) }
		var candidates: [VerificationCandidate] = []
		for item in manifest.file {
			try Task.checkCancellation()
			let relativePath = try Self.safeRelativePath(item.path)
			let destination = try installFile(at: relativePath, inside: installDirectory)
			guard let status = try destination.stat() else {
				candidates.append(VerificationCandidate(item: item, relativePath: relativePath))
				continue
			}
			guard status.st_mode & S_IFMT == S_IFREG, status.st_nlink == 1,
				status.st_size >= 0
			else {
				throw InstallerError.unsafeInstallerTemporaryFile(destination.url)
			}
			candidates.append(
				VerificationCandidate(
					item: item,
					relativePath: relativePath,
					size: Int64(status.st_size)
				)
			)
		}
		let hashedFiles = candidates.filter {
			$0.size == $0.item.byteCount
				&& (verifyAllExistingFiles || previousFiles?[$0.item.path] == nil)
		}
		let tally = VerificationTally(
			totalBytes: try Self.totalByteCount(of: hashedFiles.map(\.item)),
			totalFiles: hashedFiles.count
		)
		let monitor = hashedFiles.isEmpty ? nil : Self.monitorVerification(tally, progress)

		var pending: [ManifestFile] = []
		do {
			let decisions = try await withThrowingTaskGroup(of: (Int, Bool).self) { group in
				var decisions = [Bool](repeating: false, count: candidates.count)
				var nextIndex = 0
				func addNext() {
					guard nextIndex < candidates.count else { return }
					let index = nextIndex
					nextIndex += 1
					let candidate = candidates[index]
					let previousFile = previousFiles?[candidate.item.path]
					group.addTask {
						let needsDownload = try await self.needsDownload(
							candidate,
							previousFile: previousFile,
							verifyAllExistingFiles: verifyAllExistingFiles,
							installDirectory: installDirectory,
							tally: tally,
							willHash: willHash,
							didRead: didRead
						)
						return (index, needsDownload)
					}
				}
				for _ in 0..<AppConstants.IO.verificationConcurrency { addNext() }
				do {
					while let (index, needsDownload) = try await group.next() {
						decisions[index] = needsDownload
						addNext()
					}
				} catch {
					group.cancelAll()
					throw error
				}
				return decisions
			}
			pending = zip(candidates, decisions).filter(\.1).map(\.0.item)
		} catch {
			monitor?.cancel()
			_ = await monitor?.value
			throw error
		}

		guard let monitor else { return PendingDownloads(files: pending, lastSequence: 0) }
		monitor.cancel()
		let sequence = await monitor.value + 1
		await progress(tally.snapshot(sequence: sequence))
		return PendingDownloads(files: pending, lastSequence: sequence)
	}

	/// Hashes on the concurrent pool so synchronous file reads never occupy the caller's
	/// executor.
	@concurrent
	private func needsDownload(
		_ candidate: VerificationCandidate,
		previousFile: ManifestFile?,
		verifyAllExistingFiles: Bool,
		installDirectory: InstallerDirectory,
		tally: VerificationTally,
		willHash: @escaping @Sendable (String) -> Void,
		didRead: @escaping @Sendable (Int) -> Void
	) async throws -> Bool {
		let item = candidate.item
		tally.begin(file: item.path)
		return try Self.needsDownload(
			item,
			destinationSize: candidate.size,
			previousFile: previousFile,
			verifyAllExistingFiles: verifyAllExistingFiles,
			checksum: {
				defer { tally.finishFile() }
				willHash(item.path)
				let destination = try installFile(
					at: candidate.relativePath,
					inside: installDirectory
				)
				let descriptor = try destination.open(
					flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW
				)
				defer { _ = close(descriptor) }
				return try ManifestChecksum.checksum(
					ofFileDescriptor: descriptor,
					expected: item.hash,
					onRead: { count in
						tally.add(bytes: count)
						didRead(count)
					}
				)
			}
		)
	}

	/// Emits verification snapshots on the progress cadence until cancelled; returns the last
	/// sequence it used.
	private static func monitorVerification(
		_ tally: VerificationTally,
		_ progress: @escaping ProgressHandler
	) -> Task<UInt64, Never> {
		Task {
			var sequence: UInt64 = 0
			while !Task.isCancelled {
				sequence += 1
				await progress(tally.snapshot(sequence: sequence))
				do {
					try await Task.sleep(for: AppConstants.Network.progressEmissionInterval)
				} catch {
					break
				}
			}
			return sequence
		}
	}
}

/// A manifest file with the destination state observed before hashing.
struct VerificationCandidate: Sendable {
	let item: ManifestFile
	let relativePath: String
	var size: Int64?
}

/// Thread-safe verification counters written by the concurrent hashing tasks and read by the
/// progress monitor.
final class VerificationTally: Sendable {
	private struct State {
		var verifiedBytes: Int64 = 0
		var verifiedFiles = 0
		var currentFile = ""
	}

	private let totalBytes: Int64
	private let totalFiles: Int
	private let state = Mutex(State())

	init(totalBytes: Int64, totalFiles: Int) {
		self.totalBytes = totalBytes
		self.totalFiles = totalFiles
	}

	func begin(file: String) {
		state.withLock { $0.currentFile = file }
	}

	func add(bytes: Int) {
		state.withLock { $0.verifiedBytes += Int64(bytes) }
	}

	func finishFile() {
		state.withLock { $0.verifiedFiles += 1 }
	}

	func snapshot(sequence: UInt64) -> DownloadProgress {
		let current = state.withLock { $0 }
		return DownloadProgress(
			downloadedBytes: min(current.verifiedBytes, totalBytes),
			totalBytes: totalBytes,
			completedFiles: current.verifiedFiles,
			totalFiles: totalFiles,
			currentFile: current.currentFile,
			isVerifying: true,
			sequence: sequence
		)
	}
}
