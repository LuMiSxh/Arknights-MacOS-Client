// SPDX-License-Identifier: MPL-2.0

import Foundation

extension PresetCatalogService {
	/// Applies the last downloaded tag manifest, then fetches the repository's current one once
	/// per launch without delaying the gallery.
	func prepareWallpaperTags() async {
		if !hasLoadedWallpaperTagCache {
			hasLoadedWallpaperTagCache = true
			if let data = await readBoundedCache(at: cachedWallpaperTagsFile) {
				do {
					tagStore.apply(try WallpaperTagCatalog.decode(data))
				} catch {
					log.error(
						"Ignored cached wallpaper tags: \(launcherDiagnosticDescription(for: error))"
					)
				}
			}
		}
		guard !hasRequestedWallpaperTags else { return }
		hasRequestedWallpaperTags = true
		Task { [weak self] in await self?.refreshWallpaperTags() }
	}

	@discardableResult
	func refreshWallpaperTags() async -> Bool {
		let epoch = cacheEpoch
		do {
			var request = URLRequest(url: wallpaperTagsURL)
			request.cachePolicy = .reloadRevalidatingCacheData
			request.setValue("application/json", forHTTPHeaderField: "Accept")
			let (data, response) = try await loader.data(
				for: request,
				maximumBytes: AppConstants.Presets.wallpaperTagsMaximumBytes
			)
			guard cacheEpoch == epoch else { return false }
			guard response.statusCode == 200 else {
				log.info(
					"Kept bundled wallpaper tags; manifest returned HTTP \(response.statusCode)")
				return false
			}
			let tags = try WallpaperTagCatalog.decode(data)
			tagStore.apply(tags)
			log.info("Loaded \(tags.count) wallpaper tag entries from the repository")
			do {
				try data.write(to: cachedWallpaperTagsFile, options: .atomic)
			} catch {
				log.error(
					"Failed to cache wallpaper tags: \(launcherDiagnosticDescription(for: error))")
			}
			return true
		} catch {
			guard cacheEpoch == epoch else { return false }
			log.error(
				"Failed to fetch wallpaper tags: \(launcherDiagnosticDescription(for: error))")
			return false
		}
	}

	private func readBoundedCache(at url: URL) async -> Data? {
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }
		do {
			return try Self.readBoundedFile(
				at: url, maximumBytes: AppConstants.Presets.wallpaperTagsMaximumBytes)
		} catch {
			log.error(
				"Failed to read cached wallpaper tags: \(launcherDiagnosticDescription(for: error))"
			)
			return nil
		}
	}
}
