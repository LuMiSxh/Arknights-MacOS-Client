// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Darwin
import Foundation
import OSLog
import Synchronization

extension GameInstaller {
	struct PendingDownloads: Sendable {
		let files: [ManifestFile]
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
		let candidateList = candidates
		func decideDownloads() async throws -> [Bool] {
			var decisions = [Bool](repeating: false, count: candidateList.count)
			try await withWindowedTaskGroup(
				Array(candidateList.indices),
				limit: AppConstants.IO.verificationConcurrency,
				operation: { index in
					let candidate = candidateList[index]
					let needsDownload = try await self.needsDownload(
						candidate,
						previousFile: previousFiles?[candidate.item.path],
						verifyAllExistingFiles: verifyAllExistingFiles,
						installDirectory: installDirectory,
						tally: tally,
						willHash: willHash,
						didRead: didRead
					)
					return (index, needsDownload)
				},
				consume: { decisions[$0.0] = $0.1 }
			)
			return decisions
		}
		let monitored = !hashedFiles.isEmpty
		let decisions: [Bool]
		if monitored {
			decisions = try await InstallProgressMonitor.run(
				interval: AppConstants.Network.progressEmissionInterval,
				emit: { await progress(tally.snapshot(sequence: tally.nextSequence())) },
				operation: decideDownloads
			)
		} else {
			decisions = try await decideDownloads()
		}
		let pending = zip(candidates, decisions).filter(\.1).map(\.0.item)
		guard monitored else { return PendingDownloads(files: pending, lastSequence: 0) }
		let sequence = tally.nextSequence()
		await progress(tally.snapshot(sequence: sequence))
		return PendingDownloads(files: pending, lastSequence: sequence)
	}

	// Hashes on the concurrent pool so synchronous file reads never occupy the caller's
	// executor.
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
}

struct VerificationCandidate: Sendable {
	let item: ManifestFile
	let relativePath: String
	var size: Int64?
}

// Thread-safe verification counters written by the concurrent hashing tasks and read by the
// progress monitor.
final class VerificationTally: Sendable {
	private struct State {
		var verifiedBytes: Int64 = 0
		var verifiedFiles = 0
		var currentFile = ""
		var sequence: UInt64 = 0
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

	func nextSequence() -> UInt64 {
		state.withLock { state in
			state.sequence += 1
			return state.sequence
		}
	}
}
