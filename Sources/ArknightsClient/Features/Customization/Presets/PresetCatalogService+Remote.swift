// SPDX-License-Identifier: MPL-2.0

import Foundation

extension PresetCatalogService {
	@discardableResult
	func refreshAvatarsFromRemote() async -> [PresetAvatar] {
		let epoch = cacheEpoch
		do {
			await log.info("Fetching remote character table from GameData…")
			let request = URLRequest(url: Self.characterTableURL)
			let (data, response) = try await loader.data(
				for: request,
				maximumBytes: AppConstants.Presets.characterCatalogMaximumBytes
			)
			guard cacheEpoch == epoch else { return [] }
			guard response.statusCode == 200 else { throw URLError(.badServerResponse) }

			let parsed = try await Task.detached(priority: .utility) { () -> [PresetAvatar] in
				let rawEntries = try JSONDecoder().decode(
					[String: RawCharacterEntry].self,
					from: data
				)
				return rawEntries.compactMap { characterID, entry in
					guard Self.isValidAvatarIdentifier(characterID),
						entry.isNotObtainable != true,
						let rarity = entry.rarity, !rarity.isEmpty
					else { return nil }
					let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
					guard !name.isEmpty else { return nil }
					return PresetAvatar(
						id: characterID,
						name: name,
						filename: "\(characterID).png",
						rarity: rarity,
						appellation: entry.appellation,
						profession: entry.profession,
						subProfessionID: entry.subProfessionID,
						nationID: entry.nationID,
						groupID: entry.groupID,
						teamID: entry.teamID,
						tagList: entry.tagList
					)
				}.sorted(by: Self.avatarSortOrder)
			}.value

			guard cacheEpoch == epoch else { return [] }
			guard !parsed.isEmpty else { return [] }
			memoryCachedAvatars = parsed
			await writeJSONCache(
				parsed,
				to: cachedAvatarsFile,
				maximumBytes: AppConstants.Presets.characterCatalogMaximumBytes,
				epoch: epoch
			)
			guard cacheEpoch == epoch else { return [] }
			await log.info("Successfully indexed \(parsed.count) operators into local cache")
			guard cacheEpoch == epoch else { return [] }
			return parsed
		} catch {
			guard cacheEpoch == epoch else { return [] }
			await log.error("Failed to fetch remote character table: \(error.localizedDescription)")
			guard cacheEpoch == epoch else { return [] }
			return []
		}
	}

	@discardableResult
	func refreshWallpapersFromRemote() async -> [PresetWallpaper] {
		let epoch = cacheEpoch
		do {
			await log.info("Fetching official wallpapers from Yostar Fankit API…")
			var wallpapers: [PresetWallpaper] = []

			for page in 1...AppConstants.Presets.wallpaperPageLimit {
				guard
					let pageURL = URL(
						string:
							"https://www.arknights.global/api/resource/gallery/list?index=\(page)&size=\(AppConstants.Presets.wallpaperPageSize)"
					)
				else { break }

				var request = URLRequest(url: pageURL)
				request.setValue(
					"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
					forHTTPHeaderField: "User-Agent"
				)
				request.setValue("application/json", forHTTPHeaderField: "Accept")
				let (data, response) = try await loader.data(
					for: request,
					maximumBytes: AppConstants.Presets.wallpaperCatalogMaximumBytes
				)
				guard cacheEpoch == epoch else { return [] }
				guard response.statusCode == 200 else { break }

				let responseObject = try JSONDecoder().decode(
					YostarGalleryResponse.self, from: data)
				let rows = responseObject.data?.rows ?? responseObject.data?.list ?? []
				guard !rows.isEmpty else { break }

				for row in rows.prefix(AppConstants.Presets.wallpaperPageSize) {
					if let wallpaper = Self.wallpaper(
						from: row,
						page: page,
						ordinal: wallpapers.count + 1
					) {
						wallpapers.append(wallpaper)
					}
				}

				if rows.count < AppConstants.Presets.wallpaperPageSize { break }
			}

			guard !wallpapers.isEmpty else { return [] }
			guard cacheEpoch == epoch else { return [] }
			memoryCachedWallpapers = wallpapers
			await writeJSONCache(
				wallpapers,
				to: cachedWallpapersFile,
				maximumBytes: AppConstants.Presets.wallpaperCatalogMaximumBytes,
				epoch: epoch
			)
			guard cacheEpoch == epoch else { return [] }
			await log.info(
				"Successfully loaded \(wallpapers.count) official wallpapers from Yostar"
			)
			guard cacheEpoch == epoch else { return [] }
			return wallpapers
		} catch {
			guard cacheEpoch == epoch else { return [] }
			await log.error("Failed to fetch official wallpapers: \(error.localizedDescription)")
			guard cacheEpoch == epoch else { return [] }
			return []
		}
	}

	static func wallpaper(
		from row: YostarGalleryRow,
		page: Int,
		ordinal: Int
	) -> PresetWallpaper? {
		guard let rawURL = row.image1 ?? row.smallImage,
			let url = validatedRemoteAssetURL(from: rawURL)
		else { return nil }

		let title = row.title.map { String($0.prefix(160)) } ?? ""
		return PresetWallpaper(
			id: row.id.map { "wp_\($0)" } ?? "wp_\(page)_\(ordinal - 1)",
			title: title,
			fallbackOrdinal: title.isEmpty ? ordinal : nil,
			url: url,
			thumbnailURL: row.smallImage.flatMap(validatedRemoteAssetURL(from:)),
			author: row.author,
			description: row.description
		)
	}

	static func isValidAvatar(_ avatar: PresetAvatar) -> Bool {
		isValidAvatarIdentifier(avatar.id)
			&& avatar.filename == "\(avatar.id).png"
			&& !avatar.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	static func isValidAvatarIdentifier(_ identifier: String) -> Bool {
		guard identifier.hasPrefix("char_"),
			identifier.count <= AppConstants.Presets.avatarIdentifierMaximumLength
		else { return false }
		return identifier.unicodeScalars.allSatisfy { scalar in
			scalar.isASCII
				&& (CharacterSet.alphanumerics.contains(scalar) || scalar == "_")
		}
	}

	static func isValidWallpaper(_ wallpaper: PresetWallpaper) -> Bool {
		isAllowedRemoteAssetURL(wallpaper.url)
			&& wallpaper.thumbnailURL.map(isAllowedRemoteAssetURL) != false
	}

	static func validatedRemoteAssetURL(from raw: String) -> URL? {
		guard var components = URLComponents(string: raw) else { return nil }
		components.query = nil
		components.fragment = nil
		guard let url = components.url, isAllowedRemoteAssetURL(url) else { return nil }
		return url
	}

	static func isAllowedRemoteAssetURL(_ url: URL) -> Bool {
		guard url.scheme?.lowercased() == "https",
			url.user == nil,
			url.password == nil,
			url.port == nil || url.port == 443,
			let host = url.host?.lowercased()
		else { return false }
		return host == "cdn.jsdelivr.net"
			|| host == "raw.githubusercontent.com"
			|| host == "yo-star.com"
			|| host.hasSuffix(".yo-star.com")
			|| host == "arknights.global"
			|| host.hasSuffix(".arknights.global")
	}

	private static func avatarSortOrder(_ lhs: PresetAvatar, _ rhs: PresetAvatar) -> Bool {
		if lhs.id == "char_002_amiya" { return true }
		if rhs.id == "char_002_amiya" { return false }
		let lhsTier = tierRank(lhs.rarity)
		let rhsTier = tierRank(rhs.rarity)
		if lhsTier != rhsTier { return lhsTier > rhsTier }
		return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
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
