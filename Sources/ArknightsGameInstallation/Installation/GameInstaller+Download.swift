// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Darwin
import Foundation
import OSLog

/// One manifest file from request to installed byte: retrying across CDNs, then hashing the
/// completed partial before an atomic rename promotes it.
extension GameInstaller {
	func addDownload(
		_ item: ManifestFile,
		manifest: GameManifest,
		cdn: CDNConfiguration,
		installDirectory: InstallerDirectory,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler,
		region: GameRegion,
		reuse: ReuseSession,
		to group: inout ThrowingTaskGroup<Int64, any Error>
	) {
		group.addTask {
			if try await reuseFromOtherRegions(
				item,
				installDirectory: installDirectory,
				session: reuse,
				counter: counter,
				progress: progress
			) {
				return 0
			}
			return try await downloadWithRetry(
				item,
				source: manifest.source,
				cdn: cdn,
				installDirectory: installDirectory,
				counter: counter,
				progress: progress,
				region: region
			)
		}
	}

	private func downloadWithRetry(
		_ item: ManifestFile,
		source: String,
		cdn: CDNConfiguration,
		installDirectory: InstallerDirectory,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler,
		region: GameRegion
	) async throws -> Int64 {
		let maxAttempts = AppConstants.Network.maxDownloadAttempts
		for attempt in 1...maxAttempts {
			do {
				return try await download(
					item,
					source: source,
					baseURL: attempt == 1 ? cdn.primaryCdn : cdn.backUpCdn,
					installDirectory: installDirectory,
					counter: counter,
					progress: progress,
					region: region
				)
			} catch is CancellationError {
				throw CancellationError()
			} catch {
				if attempt == maxAttempts { throw error }
				await progress(await counter.resetRate(file: item.path))
				log?.debug(
					"Retrying \(item.path) (attempt \(attempt + 1)/\(maxAttempts)) after: "
						+ launcherDiagnosticDescription(for: error)
				)
				try await Task.sleep(for: AppConstants.Network.retryBackoffStep * attempt)
			}
		}
		throw LauncherError.invalidResponse
	}

	func finishDownload(
		_ item: ManifestFile,
		partial: InstallerFile,
		partialDescriptor: Int32,
		destination: InstallerFile,
		metadataFile: InstallerFile,
		countedBytes: Int64,
		networkBytes: Int64,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler
	) async throws {
		var status = stat()
		guard fstat(partialDescriptor, &status) == 0,
			status.st_mode & S_IFMT == S_IFREG,
			status.st_nlink == 1
		else {
			throw InstallerError.unsafeInstallerTemporaryFile(partial.url)
		}
		let actualSize = Int64(status.st_size)
		guard actualSize == item.byteCount else {
			throw InstallerError.downloadedSizeMismatch(
				path: item.path,
				expected: item.byteCount,
				actual: actualSize
			)
		}

		let checksum = try InstallerSignposts.measure("Hash") {
			try ManifestChecksum.checksum(ofFileDescriptor: partialDescriptor, expected: item.hash)
		}
		guard ManifestChecksum.matches(checksum, expected: item.hash) else {
			try await Self.rollBack(
				FileHandle(fileDescriptor: partialDescriptor, closeOnDealloc: false),
				of: item,
				truncatingTo: 0,
				counted: countedBytes,
				network: networkBytes,
				reportsProgress: true,
				rewinds: false,
				synchronizes: true,
				counter: counter,
				progress: progress
			)
			throw InstallerError.checksumMismatch(
				path: item.path,
				expected: item.hash,
				actual: checksum
			)
		}

		try Task.checkCancellation()
		try InstallerSignposts.measure("Promote") {
			try partial.rename(to: destination)
		}
		try InstallerSignposts.measure("Fsync") {
			try destination.synchronizeParent()
		}
		do {
			try metadataFile.unlink()
		} catch {
			log?.error(
				"Could not remove resume metadata for \(item.path): \(error.localizedDescription)"
			)
		}
	}
}
