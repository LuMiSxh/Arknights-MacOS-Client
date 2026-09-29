// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation
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
		installDirectory: InstallerInstallDirectory,
		previousFiles: [String: ManifestFile]?,
		verifyAllExistingFiles: Bool,
		progress: @escaping ProgressHandler
	) async throws -> PendingDownloads {
		var candidates:
			[(
				item: ManifestFile, destination: InstallerFilePath, size: Int64?,
				identity: InstallerFileIdentity?
			)] = []
		for item in manifest.file {
			try Task.checkCancellation()
			let relativePath = try Self.safeRelativePath(item.path)
			let destination = try installFile(at: relativePath, inside: installDirectory)
			guard let status = try destination.stat() else {
				candidates.append((item, destination, nil, nil))
				continue
			}
			guard status.st_mode & S_IFMT == S_IFREG, status.st_nlink == 1,
				status.st_size >= 0
			else {
				throw LauncherError.unsafeInstallerTemporaryFile(destination.url)
			}
			candidates.append(
				(item, destination, Int64(status.st_size), InstallerFileIdentity(status))
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
			for candidate in candidates {
				try Task.checkCancellation()
				let item = candidate.item
				tally.begin(file: item.path)
				let needsDownload = try Self.needsDownload(
					item,
					destinationSize: candidate.size,
					previousFile: previousFiles?[item.path],
					verifyAllExistingFiles: verifyAllExistingFiles,
					checksum: {
						defer { tally.finishFile() }
						let descriptor = try candidate.destination.open(
							flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW
						)
						defer { _ = close(descriptor) }
						var before = stat()
						guard fstat(descriptor, &before) == 0,
							before.st_mode & S_IFMT == S_IFREG,
							before.st_nlink == 1,
							InstallerFileIdentity(before) == candidate.identity
						else {
							throw LauncherError.unsafeInstallerTemporaryFile(
								candidate.destination.url
							)
						}
						let checksum = try ManifestChecksum.checksum(
							ofFileDescriptor: descriptor,
							expected: item.hash,
							onRead: tally.add(bytes:)
						)
						var after = stat()
						guard fstat(descriptor, &after) == 0,
							InstallerFileIdentity(after) == InstallerFileIdentity(before),
							after.st_size == before.st_size,
							let current = try candidate.destination.stat(),
							InstallerFileIdentity(current) == InstallerFileIdentity(before)
						else {
							throw LauncherError.unsafeInstallerTemporaryFile(
								candidate.destination.url
							)
						}
						return checksum
					}
				)
				if needsDownload { pending.append(item) }
			}
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

/// Thread-safe verification counters written by the synchronous hashing loop and read by the
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
