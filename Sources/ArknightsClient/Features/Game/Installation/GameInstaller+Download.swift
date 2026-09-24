// SPDX-License-Identifier: MPL-2.0

import Foundation

/// One manifest file from request to installed byte: retrying across CDNs, then verifying
/// and committing the completed `.part` file.
extension GameInstaller {
	func addDownload(
		_ item: ManifestFile,
		manifest: GameManifest,
		cdn: CDNConfiguration,
		installDirectory: URL,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler,
		region: GameRegion,
		to group: inout ThrowingTaskGroup<Int64, any Error>
	) {
		group.addTask {
			try await downloadWithRetry(
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
		installDirectory: URL,
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
				await log?.debug(
					"Retrying \(item.path) (attempt \(attempt + 1)/\(maxAttempts)) after: "
						+ error.localizedDescription
				)
				try await Task.sleep(for: AppConstants.Network.retryBackoffStep * attempt)
			}
		}
		throw LauncherError.invalidResponse
	}

	func finishDownload(
		_ item: ManifestFile,
		partial: URL,
		destination: URL,
		installDirectory: URL,
		countedBytes: Int64,
		networkBytes: Int64,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler
	) async throws {
		try assertNoSymbolicLinks(from: installDirectory, through: partial)
		try assertNoSymbolicLinks(from: installDirectory, through: destination)
		let actualSize = try fileSize(at: partial) ?? 0
		guard actualSize == item.byteCount else {
			throw LauncherError.downloadedSizeMismatch(
				path: item.path,
				expected: item.byteCount,
				actual: actualSize
			)
		}
		let checksum = try ManifestChecksum.checksum(of: partial, expected: item.hash)
		guard ManifestChecksum.matches(checksum, expected: item.hash) else {
			try fileManager.removeItem(at: partial)
			await progress(
				await counter.remove(
					bytes: countedBytes,
					networkBytes: networkBytes,
					file: item.path
				)
			)
			throw LauncherError.checksumMismatch(
				path: item.path, expected: item.hash, actual: checksum)
		}
		if fileManager.fileExists(atPath: destination.path) {
			try fileManager.removeItem(at: destination)
		}
		try fileManager.moveItem(at: partial, to: destination)
	}

	func fileSize(at url: URL) throws -> Int64? {
		do {
			let attributes = try fileManager.attributesOfItem(atPath: url.path)
			return (attributes[.size] as? NSNumber)?.int64Value
		} catch let error as CocoaError
			where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile
		{
			return nil
		} catch let error as POSIXError where error.code == .ENOENT {
			return nil
		}
	}
}
