// SPDX-License-Identifier: MPL-2.0

import Foundation

extension PresetCatalogService {
	@discardableResult
	func refreshAvatarsFromRemote() async -> [PresetAvatar] {
		do {
			await log.info("Fetching remote character table from GameData…")
			let request = URLRequest(url: Self.characterTableURL)
			let (data, response) = try await loader.data(
				for: request,
				maximumBytes: AppConstants.Presets.characterCatalogMaximumBytes
			)
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
						rarity: rarity
					)
				}.sorted(by: Self.avatarSortOrder)
			}.value

			guard !parsed.isEmpty else { return [] }
			memoryCachedAvatars = parsed
			await writeJSONCache(
				parsed,
				to: cachedAvatarsFile,
				maximumBytes: AppConstants.Presets.characterCatalogMaximumBytes
			)
			await log.info("Successfully indexed \(parsed.count) operators into local cache")
			return parsed
		} catch {
			await log.error("Failed to fetch remote character table: \(error.localizedDescription)")
			return []
		}
	}

	@discardableResult
	func refreshWallpapersFromRemote() async -> [PresetWallpaper] {
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
				guard response.statusCode == 200 else { break }

				let responseObject = try JSONDecoder().decode(
					YostarGalleryResponse.self, from: data)
				let rows = responseObject.data?.rows ?? responseObject.data?.list ?? []
				guard !rows.isEmpty else { break }

				for row in rows.prefix(AppConstants.Presets.wallpaperPageSize) {
					guard let rawURL = row.image1 ?? row.smallImage,
						let url = Self.validatedRemoteAssetURL(from: rawURL)
					else { continue }

					let trimmedTitle = row.title?.trimmingCharacters(in: .whitespacesAndNewlines)
					let title: String
					if let trimmedTitle, !trimmedTitle.isEmpty {
						title = String(trimmedTitle.prefix(160))
					} else {
						title = "Wallpaper \(wallpapers.count + 1)"
					}
					let thumbnailURL = row.smallImage.flatMap(Self.validatedRemoteAssetURL(from:))
					wallpapers.append(
						PresetWallpaper(
							id: "wp_\(page)_\(wallpapers.count)",
							title: title,
							url: url,
							thumbnailURL: thumbnailURL
						)
					)
				}

				if rows.count < AppConstants.Presets.wallpaperPageSize { break }
			}

			guard !wallpapers.isEmpty else { return [] }
			memoryCachedWallpapers = wallpapers
			await writeJSONCache(
				wallpapers,
				to: cachedWallpapersFile,
				maximumBytes: AppConstants.Presets.wallpaperCatalogMaximumBytes
			)
			await log.info(
				"Successfully loaded \(wallpapers.count) official wallpapers from Yostar"
			)
			return wallpapers
		} catch {
			await log.error("Failed to fetch official wallpapers: \(error.localizedDescription)")
			return []
		}
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
