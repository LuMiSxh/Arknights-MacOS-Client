// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

extension PresetCatalogService {
	// Applies the last downloaded tag manifest, then fetches the repository's current one once
	// per launch without delaying the gallery.
	func prepareWallpaperTags() async {
		if !hasLoadedWallpaperTagCache {
			hasLoadedWallpaperTagCache = true
			if let data = await readBoundedCache(at: cachedWallpaperTagsFile) {
				log.attempt(.customization, "apply-cached-wallpaper-tags") {
					tagStore.apply(try WallpaperTagCatalog.decode(data))
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
				log.warning(
					.customization, "wallpaper-tags-kept", ["httpStatus": response.statusCode])
				return false
			}
			let tags = try WallpaperTagCatalog.decode(data)
			tagStore.apply(tags)
			log.info(.customization, "wallpaper-tags-loaded", ["count": tags.count])
			log.attempt(.customization, "cache-wallpaper-tags") {
				try data.write(to: cachedWallpaperTagsFile, options: .atomic)
			}
			return true
		} catch {
			guard cacheEpoch == epoch else { return false }
			log.warning(.customization, "wallpaper-tags-fetch-failed", error: error)
			return false
		}
	}

	private func readBoundedCache(at url: URL) async -> Data? {
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }
		do {
			return try BoundedFileReader.readRegularFile(
				at: url, maximumBytes: AppConstants.Presets.wallpaperTagsMaximumBytes)
		} catch {
			log.warning(.customization, "wallpaper-tags-read-failed", error: error)
			return nil
		}
	}
}
