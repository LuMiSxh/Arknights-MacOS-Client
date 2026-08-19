// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

actor PresetCatalogService {
	static let shared = PresetCatalogService()

	private static let characterTableURL = URL(
		string:
			"https://cdn.jsdelivr.net/gh/Kengxxiao/ArknightsGameData_YoStar@main/en_US/gamedata/excel/character_table.json"
	)!

	private let cacheDirectory: URL
	private let cachedAvatarsFile: URL
	private let cachedWallpapersFile: URL
	private let log: LauncherLog
	private var memoryCachedAvatars: [PresetAvatar]?
	private var memoryCachedWallpapers: [PresetWallpaper]?

	init(log: LauncherLog? = nil) {
		let paths = AppPaths()
		self.log = log ?? LauncherLog(fileURL: paths.launcherLogFile)
		cacheDirectory = paths.cacheRoot.appending(
			path: "PresetGallery",
			directoryHint: .isDirectory
		)
		cachedAvatarsFile = cacheDirectory.appending(path: "avatars_index_v1.json")
		cachedWallpapersFile = cacheDirectory.appending(path: "wallpapers_index_v1.json")
		try? FileManager.default.createDirectory(
			at: cacheDirectory, withIntermediateDirectories: true
		)
	}

	// MARK: - Avatars (Issue #24)

	func fetchAvatars() async -> [PresetAvatar] {
		if let memoryCachedAvatars, !memoryCachedAvatars.isEmpty {
			return memoryCachedAvatars
		}

		if let diskData = try? Data(contentsOf: cachedAvatarsFile),
			let cached = try? JSONDecoder().decode([PresetAvatar].self, from: diskData),
			!cached.isEmpty
		{
			memoryCachedAvatars = cached
			Task { [weak self] in await self?.refreshAvatarsFromRemote() }
			return cached
		}

		let remote = await refreshAvatarsFromRemote()
		return !remote.isEmpty ? remote : fallbackCuratedAvatars
	}

	@discardableResult
	private func refreshAvatarsFromRemote() async -> [PresetAvatar] {
		do {
			await log.info("Fetching remote character table from GameData…")
			let (data, response) = try await URLSession.shared.data(from: Self.characterTableURL)
			guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
				throw URLError(.badServerResponse)
			}

			let parsed = try await Task.detached(priority: .utility) { () -> [PresetAvatar] in
				let rawDict = try JSONDecoder().decode([String: RawCharacterEntry].self, from: data)
				var results: [PresetAvatar] = []

				for (charID, entry) in rawDict {
					guard charID.hasPrefix("char_"),
						entry.isNotObtainable != true,
						let rarity = entry.rarity, !rarity.isEmpty,
						!entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
					else { continue }

					results.append(
						PresetAvatar(
							id: charID,
							name: entry.name.trimmingCharacters(in: .whitespacesAndNewlines),
							filename: "\(charID).png",
							rarity: rarity
						)
					)
				}

				return results.sorted { lhs, rhs in
					if lhs.id == "char_002_amiya" { return true }
					if rhs.id == "char_002_amiya" { return false }
					let lhsTier = tierRank(lhs.rarity)
					let rhsTier = tierRank(rhs.rarity)
					if lhsTier != rhsTier { return lhsTier > rhsTier }
					return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
				}
			}.value

			if !parsed.isEmpty {
				memoryCachedAvatars = parsed
				if let encoded = try? JSONEncoder().encode(parsed) {
					try? encoded.write(to: cachedAvatarsFile, options: .atomic)
				}
				await log.info("Successfully indexed \(parsed.count) operators into local cache")
				return parsed
			}
		} catch {
			await log.debug("Remote character table fetch skipped: \(error.localizedDescription)")
		}
		return []
	}

	// MARK: - Wallpapers (Issue #30)

	func fetchWallpapers() async -> [PresetWallpaper] {
		if let memoryCachedWallpapers, !memoryCachedWallpapers.isEmpty {
			return memoryCachedWallpapers
		}

		if let diskData = try? Data(contentsOf: cachedWallpapersFile),
			let cached = try? JSONDecoder().decode([PresetWallpaper].self, from: diskData),
			!cached.isEmpty
		{
			memoryCachedWallpapers = cached
			Task { [weak self] in await self?.refreshWallpapersFromRemote() }
			return cached
		}

		let remote = await refreshWallpapersFromRemote()
		return !remote.isEmpty ? remote : fallbackWallpapers
	}

	@discardableResult
	private func refreshWallpapersFromRemote() async -> [PresetWallpaper] {
		do {
			await log.info("Fetching official wallpapers from Yostar Fankit API…")
			var allWallpapers: [PresetWallpaper] = []
			let pageSize = 50

			for page in 1...5 {
				guard
					let pageURL = URL(
						string:
							"https://www.arknights.global/api/resource/gallery/list?index=\(page)&size=\(pageSize)"
					)
				else { break }

				var request = URLRequest(url: pageURL)
				request.setValue(
					"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
					forHTTPHeaderField: "User-Agent"
				)
				request.setValue("application/json", forHTTPHeaderField: "Accept")
				let (data, response) = try await URLSession.shared.data(for: request)
				guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
					break
				}

				let responseObj = try JSONDecoder().decode(YostarGalleryResponse.self, from: data)
				let rows = responseObj.data?.rows ?? responseObj.data?.list ?? []
				guard !rows.isEmpty else { break }

				for row in rows {
					guard let rawURL = row.image1 ?? row.smallImage,
						let url = URL(string: cleanWallpaperURL(rawURL))
					else { continue }

					let title =
						row.title?.trimmingCharacters(in: .whitespacesAndNewlines)
						?? "Wallpaper \(allWallpapers.count + 1)"
					let thumb = row.smallImage.flatMap { URL(string: $0) }
					allWallpapers.append(
						PresetWallpaper(
							id: "wp_\(allWallpapers.count)_\(url.lastPathComponent)",
							title: title,
							url: url,
							thumbnailURL: thumb
						)
					)
				}

				if rows.count < pageSize {
					break
				}
			}

			if !allWallpapers.isEmpty {
				memoryCachedWallpapers = allWallpapers
				if let encoded = try? JSONEncoder().encode(allWallpapers) {
					try? encoded.write(to: cachedWallpapersFile, options: .atomic)
				}
				await log.info(
					"Successfully loaded \(allWallpapers.count) official wallpapers from Yostar"
				)
				return allWallpapers
			}
		} catch {
			await log.error("Failed to fetch official wallpapers: \(error.localizedDescription)")
		}
		return []
	}

	private func cleanWallpaperURL(_ raw: String) -> String {
		raw.components(separatedBy: "?").first ?? raw
	}

	func imageData(for url: URL, cacheKey: String) async throws -> Data {
		let cachedFile = cacheDirectory.appending(path: "\(cacheKey).cache")
		if let data = try? Data(contentsOf: cachedFile), !data.isEmpty {
			return data
		}

		// 1. Primary download attempt
		do {
			let data = try await fetchImageData(from: url, cacheKey: cacheKey)
			try? data.write(to: cachedFile, options: .atomic)
			return data
		} catch {
			// 2. Fallback to GitHub Raw (PuppiizSunniiz)
			if url.host == "cdn.jsdelivr.net",
				let fallbackURL = URL(
					string:
						"https://raw.githubusercontent.com/PuppiizSunniiz/Arknight-Images/main/avatars/\(url.lastPathComponent)"
				)
			{
				do {
					let data = try await fetchImageData(from: fallbackURL, cacheKey: cacheKey)
					try? data.write(to: cachedFile, options: .atomic)
					return data
				} catch {
					// 3. Fallback to legacy Aceship if needed
					if let legacyURL = URL(
						string:
							"https://raw.githubusercontent.com/Aceship/Arknight-Images/main/avatars/\(url.lastPathComponent)"
					) {
						let data = try await fetchImageData(
							from: legacyURL,
							cacheKey: cacheKey
						)
						try? data.write(to: cachedFile, options: .atomic)
						return data
					}
				}
			}
			throw error
		}
	}

	private func fetchImageData(from url: URL, cacheKey: String) async throws -> Data {
		var request = URLRequest(url: url, timeoutInterval: 8)
		request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
		let (data, response) = try await URLSession.shared.data(for: request)
		guard let http = response as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty else {
			throw URLError(.badServerResponse)
		}

		return data
	}

	func clearCaches() async {
		memoryCachedAvatars = nil
		memoryCachedWallpapers = nil
		do {
			if FileManager.default.fileExists(atPath: cacheDirectory.path) {
				try FileManager.default.removeItem(at: cacheDirectory)
			}
			try FileManager.default.createDirectory(
				at: cacheDirectory,
				withIntermediateDirectories: true
			)
		} catch {
			await log.debug("Failed to clear preset catalog caches: \(error.localizedDescription)")
		}
	}

	func cacheSizeText() async -> String {
		let bytes = await Task.detached(priority: .utility) { [cacheDirectory] in
			return Self.directorySize(at: cacheDirectory)
		}.value
		return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
	}

	private static func directorySize(at url: URL, fileManager: FileManager = .default) -> Int64 {
		guard
			let enumerator = fileManager.enumerator(
				at: url,
				includingPropertiesForKeys: [.fileSizeKey]
			)
		else { return 0 }
		var total: Int64 = 0
		for case let fileURL as URL in enumerator {
			total += Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
		}
		return total
	}

	// MARK: - Fallbacks

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

private func tierRank(_ rarity: String?) -> Int {
	switch rarity?.uppercased() {
	case "TIER_6": 6
	case "TIER_5": 5
	case "TIER_4": 4
	case "TIER_3": 3
	case "TIER_2": 2
	case "TIER_1": 1
	default: 0
	}
}
