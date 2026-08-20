// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameInstaller {
	func addDownload(
		_ item: ManifestFile,
		manifest: GameManifest,
		cdn: CDNConfiguration,
		installDirectory: URL,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler,
		to group: inout ThrowingTaskGroup<Int64, any Error>
	) {
		group.addTask {
			try await downloadWithRetry(
				item,
				source: manifest.source,
				cdn: cdn,
				installDirectory: installDirectory,
				counter: counter,
				progress: progress
			)
		}
	}

	private func downloadWithRetry(
		_ item: ManifestFile,
		source: String,
		cdn: CDNConfiguration,
		installDirectory: URL,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler
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
					progress: progress
				)
			} catch is CancellationError {
				throw CancellationError()
			} catch {
				if attempt == maxAttempts { throw error }
				await log?.debug(
					"Retrying \(item.path) (attempt \(attempt + 1)/\(maxAttempts)) after: "
						+ error.localizedDescription
				)
				try await Task.sleep(for: AppConstants.Network.retryBackoffStep * attempt)
			}
		}
		throw LauncherError.invalidResponse
	}
}
