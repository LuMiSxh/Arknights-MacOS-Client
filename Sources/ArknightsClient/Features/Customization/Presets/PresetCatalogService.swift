// SPDX-License-Identifier: MPL-2.0

import Foundation

actor PresetCatalogService {
	static let characterTableURL = URL(
		string:
			"https://cdn.jsdelivr.net/gh/Kengxxiao/ArknightsGameData_YoStar@main/en_US/gamedata/excel/character_table.json"
	)!

	let cacheDirectory: URL
	let cachedAvatarsFile: URL
	let cachedWallpapersFile: URL
	let loader: BoundedHTTPDataLoader
	let log: LauncherLog
	var memoryCachedAvatars: [PresetAvatar]?
	var memoryCachedWallpapers: [PresetWallpaper]?
	var hasEnforcedImageCacheLimit = false
	var cacheEpoch: UInt64 = 0

	init(
		cacheDirectory: URL,
		session: URLSession = .shared,
		log: LauncherLog
	) {
		self.log = log
		self.cacheDirectory = cacheDirectory
		cachedAvatarsFile = cacheDirectory.appending(path: "avatars_index_v1.json")
		cachedWallpapersFile = cacheDirectory.appending(path: "wallpapers_index_v1.json")
		loader = BoundedHTTPDataLoader(
			session: session,
			redirectValidator: Self.isAllowedRemoteAssetURL
		)

		do {
			try FileManager.default.createDirectory(
				at: cacheDirectory,
				withIntermediateDirectories: true
			)
		} catch {
			Task {
				await log.error(
					"Failed to create preset cache directory at \(cacheDirectory.path): \(error.localizedDescription)"
				)
			}
		}
	}

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
				Task { [weak self] in await self?.refreshAvatarsFromRemote() }
				return validated
			}
		}

		let remote = await refreshAvatarsFromRemote()
		guard cacheEpoch == epoch else { return fallbackCuratedAvatars }
		return !remote.isEmpty ? remote : fallbackCuratedAvatars
	}

	func fetchWallpapers() async -> [PresetWallpaper] {
		await enforceImageCacheLimitIfNeeded()
		let epoch = cacheEpoch
		if let memoryCachedWallpapers, !memoryCachedWallpapers.isEmpty {
			return memoryCachedWallpapers
		}

		if let cached: [PresetWallpaper] = await readJSONCache(
			from: cachedWallpapersFile,
			maximumBytes: AppConstants.Presets.wallpaperCatalogMaximumBytes
		) {
			guard cacheEpoch == epoch else { return fallbackWallpapers }
			let validated = cached.filter(Self.isValidWallpaper)
			if !validated.isEmpty {
				memoryCachedWallpapers = validated
				Task { [weak self] in await self?.refreshWallpapersFromRemote() }
				return validated
			}
		}

		let remote = await refreshWallpapersFromRemote()
		guard cacheEpoch == epoch else { return fallbackWallpapers }
		return !remote.isEmpty ? remote : fallbackWallpapers
	}

	func clearCaches() async throws {
		cacheEpoch &+= 1
		memoryCachedAvatars = nil
		memoryCachedWallpapers = nil
		hasEnforcedImageCacheLimit = true
		do {
			if FileManager.default.fileExists(atPath: cacheDirectory.path) {
				try FileManager.default.removeItem(at: cacheDirectory)
			}
			try FileManager.default.createDirectory(
				at: cacheDirectory,
				withIntermediateDirectories: true
			)
		} catch {
			await log.error(
				"Failed to clear preset catalog caches at \(cacheDirectory.path): \(error.localizedDescription)"
			)
			throw error
		}
	}

	func readJSONCache<Value: Decodable>(
		from url: URL,
		maximumBytes: Int
	) async -> Value? {
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }
		do {
			let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
			let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
			guard size <= maximumBytes else {
				try FileManager.default.removeItem(at: url)
				await log.error("Removed oversized preset index at \(url.path) (\(size) bytes)")
				return nil
			}
			let data = try Self.readBoundedFile(at: url, maximumBytes: maximumBytes)
			return try JSONDecoder().decode(Value.self, from: data)
		} catch {
			await log.error(
				"Failed to read preset index at \(url.path): \(error.localizedDescription)")
			return nil
		}
	}

	func writeJSONCache<Value: Encodable>(
		_ value: Value,
		to url: URL,
		maximumBytes: Int,
		epoch: UInt64
	) async {
		guard cacheEpoch == epoch else { return }
		do {
			let data = try JSONEncoder().encode(value)
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
			await log.error(
				"Failed to write preset index at \(url.path): \(error.localizedDescription)")
		}
	}

	static func readBoundedFile(at url: URL, maximumBytes: Int) throws -> Data {
		let handle = try FileHandle(forReadingFrom: url)
		defer { handle.closeFile() }
		let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
		guard data.count <= maximumBytes else {
			throw LauncherError.remoteContentTooLarge(url, maximumBytes: maximumBytes)
		}
		return data
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

	private var fallbackWallpapers: [PresetWallpaper] {
		[
			.init(
				id: "crossing",
				title: "Crossing",
				fallbackOrdinal: nil,
				url: URL(
					string:
						"https://webusstatic.yo-star.com/web-cms-test/upload/content/2026/08/17/PAMcBwUl.png"
				)!,
				thumbnailURL: nil
			),
			.init(
				id: "x-460k",
				title: "X 460k Followers",
				fallbackOrdinal: nil,
				url: URL(
					string:
						"https://webusstatic.yo-star.com/web-cms-test/upload/content/2026/08/13/SlOn1_p6.png"
				)!,
				thumbnailURL: nil
			),
		]
	}
}
