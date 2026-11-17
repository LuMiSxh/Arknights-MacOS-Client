// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

package actor PresetCatalogService {
	static let characterTableURLs = PresetRemoteSources.characterTables

	let cacheDirectory: URL
	let cachedAvatarsFile: URL
	let cachedWallpapersFile: URL
	let cachedWallpaperTagsFile: URL
	let wallpaperTagsURL: URL
	let tagStore: WallpaperTagStore
	let loader: BoundedHTTPDataLoader
	let imageFetchLimiter = PresetImageFetchLimiter(
		limit: AppConstants.Presets.imageFetchConcurrency
	)
	package let log: LauncherLog
	var memoryCachedAvatars: [PresetAvatar]?
	var memoryCachedWallpapers: [PresetWallpaper]?
	var avatarRefresh: Task<[PresetAvatar], Never>?
	var hasEnforcedImageCacheLimit = false
	var cacheEpoch: UInt64 = 0
	var hasLoadedWallpaperTagCache = false
	var hasRequestedWallpaperTags = false

	package init(
		cacheDirectory: URL,
		session: URLSession = .shared,
		wallpaperTagsURL: URL = AppConstants.Presets.wallpaperTagsURL,
		tagStore: WallpaperTagStore = .shared,
		log: LauncherLog
	) {
		self.log = log
		self.cacheDirectory = cacheDirectory
		cachedAvatarsFile = cacheDirectory.appending(path: "avatars_index.json")
		cachedWallpapersFile = cacheDirectory.appending(path: "wallpapers_index.json")
		cachedWallpaperTagsFile = cacheDirectory.appending(path: "wallpaper_tags.json")
		self.wallpaperTagsURL = wallpaperTagsURL
		self.tagStore = tagStore
		loader = BoundedHTTPDataLoader(
			session: session,
			maximumBufferedBytes: AppConstants.Network.maximumBufferedStreamBytes,
			redirectValidator: Self.isAllowedRemoteAssetURL
		)

		log.attempt("Failed to create preset cache directory at \(cacheDirectory.path)") {
			try FileManager.default.createDirectory(
				at: cacheDirectory,
				withIntermediateDirectories: true
			)
		}
	}

	var fetcher: CheckedHTTPFetcher { CheckedHTTPFetcher(loader: loader) }

	func fetchAvatars() async -> [PresetAvatar] {
		await enforceImageCacheLimitIfNeeded()
		let epoch = cacheEpoch
		if let memoryCachedAvatars, !memoryCachedAvatars.isEmpty {
			return memoryCachedAvatars
		}

		if let cached: [PresetAvatar] = await readJSONCache(
			from: cachedAvatarsFile,
			maximumBytes: AppConstants.Presets.characterCatalogMaximumBytes
		) {
			guard cacheEpoch == epoch else { return fallbackCuratedAvatars }
			let validated = cached.filter(Self.isValidAvatar)
			if !validated.isEmpty {
				memoryCachedAvatars = validated
				avatarRefresh = Task { [weak self] in await self?.refreshAvatarsFromRemote() ?? [] }
				return validated
			}
		}

		let remote = await refreshAvatarsFromRemote()
		guard cacheEpoch == epoch else { return fallbackCuratedAvatars }
		return !remote.isEmpty ? remote : fallbackCuratedAvatars
	}

	// Waits for the refresh `fetchAvatars` started from the disk cache and returns its catalog
	// only when it differs from the one already shown, such as a renamed or newly added operator.
	func refreshedAvatars(replacing current: [PresetAvatar]) async -> [PresetAvatar]? {
		guard let avatarRefresh else { return nil }
		let epoch = cacheEpoch
		let refreshed = await avatarRefresh.value
		guard cacheEpoch == epoch, !refreshed.isEmpty, refreshed != current else { return nil }
		return refreshed
	}

	func fetchWallpapers() async -> [PresetWallpaper] {
		await enforceImageCacheLimitIfNeeded()
		await prepareWallpaperTags()
		let epoch = cacheEpoch
		if let memoryCachedWallpapers, !memoryCachedWallpapers.isEmpty {
			return memoryCachedWallpapers
		}

		if let cached: [PresetWallpaper] = await readJSONCache(
			from: cachedWallpapersFile,
			maximumBytes: AppConstants.Presets.wallpaperCatalogMaximumBytes
		) {
			guard cacheEpoch == epoch else { return [] }
			let validated = cached.filter(Self.isValidWallpaper)
			if !validated.isEmpty {
				memoryCachedWallpapers = validated
				Task { [weak self] in await self?.refreshWallpapersFromRemote() }
				return validated
			}
		}

		let remote = await refreshWallpapersFromRemote()
		guard cacheEpoch == epoch else { return [] }
		return remote
	}

	package func clearCaches() async throws {
		cacheEpoch &+= 1
		memoryCachedAvatars = nil
		avatarRefresh = nil
		memoryCachedWallpapers = nil
		hasEnforcedImageCacheLimit = true
		hasLoadedWallpaperTagCache = false
		hasRequestedWallpaperTags = false
		tagStore.resetToBundled()
		do {
			if FileManager.default.fileExists(atPath: cacheDirectory.path) {
				try FileManager.default.removeItem(at: cacheDirectory)
			}
			try FileManager.default.createDirectory(
				at: cacheDirectory,
				withIntermediateDirectories: true
			)
		} catch {
			log.error(
				"Failed to clear preset catalog caches at \(cacheDirectory.path): \(error.localizedDescription)"
			)
			throw error
		}
	}

	func readJSONCache<Value: Codable>(
		from url: URL,
		maximumBytes: Int
	) async -> Value? {
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }
		do {
			let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
			guard size <= maximumBytes else {
				try FileManager.default.removeItem(at: url)
				log.error("Removed oversized preset index at \(url.path) (\(size) bytes)")
				return nil
			}
			let store = JSONFileStore(maximumBytes: maximumBytes, prettyPrinted: false)
			guard
				let file = try store.read(PresetIndexFile<Value>.self, at: url),
				file.schemaVersion == AppConstants.Presets.indexSchemaVersion
			else { return nil }
			return file.items
		} catch {
			log.error(
				"Failed to read preset index at \(url.path): \(launcherDiagnosticDescription(for: error))"
			)
			return nil
		}
	}

	func writeJSONCache<Value: Codable>(
		_ value: Value,
		to url: URL,
		maximumBytes: Int,
		epoch: UInt64
	) async {
		guard cacheEpoch == epoch else { return }
		do {
			let data = try JSONEncoder().encode(
				PresetIndexFile(
					schemaVersion: AppConstants.Presets.indexSchemaVersion,
					items: value
				))
			guard data.count <= maximumBytes else {
				throw LauncherError.remoteContentTooLarge(url, maximumBytes: maximumBytes)
			}
			try FileManager.default.createDirectory(
				at: cacheDirectory,
				withIntermediateDirectories: true
			)
			try data.write(to: url, options: .atomic)
		} catch {
			guard cacheEpoch == epoch else { return }
			log.error(
				"Failed to write preset index at \(url.path): \(launcherDiagnosticDescription(for: error))"
			)
		}
	}

	private var fallbackCuratedAvatars: [PresetAvatar] {
		[
			.init(
				id: "char_002_amiya", name: "Amiya", filename: "char_002_amiya.png",
				rarity: "TIER_5"),
			.init(
				id: "char_003_kalts", name: "Kal'tsit", filename: "char_003_kalts.png",
				rarity: "TIER_6"),
			.init(
				id: "char_1028_texas2", name: "Texas the Omertosa",
				filename: "char_1028_texas2.png", rarity: "TIER_6"),
			.init(
				id: "char_249_mlyse", name: "Muelsyse", filename: "char_249_mlyse.png",
				rarity: "TIER_6"),
		]
	}

}

// One cached preset catalog with the format version that produced it.
private struct PresetIndexFile<Value: Codable>: Codable {
	let schemaVersion: Int
	let items: Value
}
