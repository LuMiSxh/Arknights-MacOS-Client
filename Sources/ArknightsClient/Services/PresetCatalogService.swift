// SPDX-License-Identifier: MPL-2.0

import Foundation

actor PresetCatalogService {
	static let shared = PresetCatalogService()

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

	init(
		cacheDirectory: URL? = nil,
		session: URLSession = .shared,
		log: LauncherLog? = nil
	) {
		let paths = AppPaths()
		let resolvedLog = log ?? LauncherLog(fileURL: paths.launcherLogFile)
		let resolvedCacheDirectory =
			cacheDirectory
			?? paths.cacheRoot.appending(path: "PresetGallery", directoryHint: .isDirectory)
		self.log = resolvedLog
		self.cacheDirectory = resolvedCacheDirectory
		cachedAvatarsFile = resolvedCacheDirectory.appending(path: "avatars_index_v1.json")
		cachedWallpapersFile = resolvedCacheDirectory.appending(path: "wallpapers_index_v1.json")
		loader = BoundedHTTPDataLoader(
			session: session,
			redirectValidator: Self.isAllowedRemoteAssetURL
		)

		do {
			try FileManager.default.createDirectory(
				at: resolvedCacheDirectory,
				withIntermediateDirectories: true
			)
		} catch {
			Task {
				await resolvedLog.error(
					"Failed to create preset cache directory at \(resolvedCacheDirectory.path): \(error.localizedDescription)"
				)
			}
		}
	}

	func fetchAvatars() async -> [PresetAvatar] {
		await enforceImageCacheLimitIfNeeded()
		if let memoryCachedAvatars, !memoryCachedAvatars.isEmpty {
			return memoryCachedAvatars
		}

		if let cached: [PresetAvatar] = await readJSONCache(
			from: cachedAvatarsFile,
			maximumBytes: AppConstants.Presets.characterCatalogMaximumBytes
		) {
			let validated = cached.filter(Self.isValidAvatar)
			if !validated.isEmpty {
				memoryCachedAvatars = validated
				Task { [weak self] in await self?.refreshAvatarsFromRemote() }
				return validated
			}
		}

		let remote = await refreshAvatarsFromRemote()
		return !remote.isEmpty ? remote : fallbackCuratedAvatars
	}

	func fetchWallpapers() async -> [PresetWallpaper] {
		await enforceImageCacheLimitIfNeeded()
		if let memoryCachedWallpapers, !memoryCachedWallpapers.isEmpty {
			return memoryCachedWallpapers
		}

		if let cached: [PresetWallpaper] = await readJSONCache(
			from: cachedWallpapersFile,
			maximumBytes: AppConstants.Presets.wallpaperCatalogMaximumBytes
		) {
			let validated = cached.filter(Self.isValidWallpaper)
			if !validated.isEmpty {
				memoryCachedWallpapers = validated
				Task { [weak self] in await self?.refreshWallpapersFromRemote() }
				return validated
			}
		}

		let remote = await refreshWallpapersFromRemote()
		return !remote.isEmpty ? remote : fallbackWallpapers
	}

	func clearCaches() async throws {
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

	func cacheSizeText() async -> String {
		do {
			let bytes = try await Task.detached(priority: .utility) { [cacheDirectory] in
				try Self.directorySize(at: cacheDirectory)
			}.value
			return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
		} catch {
			await log.error(
				"Failed to measure preset cache at \(cacheDirectory.path): \(error.localizedDescription)"
			)
			return ByteCountFormatter.string(fromByteCount: 0, countStyle: .file)
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
		maximumBytes: Int
	) async {
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
			await log.error(
				"Failed to write preset index at \(url.path): \(error.localizedDescription)")
		}
	}

	private static func directorySize(
		at url: URL,
		fileManager: FileManager = .default
	) throws -> Int64 {
		guard
			let enumerator = fileManager.enumerator(
				at: url,
				includingPropertiesForKeys: [.fileSizeKey]
			)
		else { return 0 }
		var total: Int64 = 0
		for case let fileURL as URL in enumerator {
			total += Int64(try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
		}
		return total
	}

	static func readBoundedFile(at url: URL, maximumBytes: Int) throws -> Data {
		let handle = try FileHandle(forReadingFrom: url)
		let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
		try handle.close()
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
				url: URL(
					string:
						"https://webusstatic.yo-star.com/web-cms-test/upload/content/2026/08/17/PAMcBwUl.png"
				)!,
				thumbnailURL: nil
			),
			.init(
				id: "x-460k",
				title: "X 460k Followers",
				url: URL(
					string:
						"https://webusstatic.yo-star.com/web-cms-test/upload/content/2026/08/13/SlOn1_p6.png"
				)!,
				thumbnailURL: nil
			),
		]
	}
}
