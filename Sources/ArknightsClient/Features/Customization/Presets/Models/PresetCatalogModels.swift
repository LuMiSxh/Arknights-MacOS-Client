// SPDX-License-Identifier: MPL-2.0

import Foundation

/// A lightweight operator avatar representation for the gallery.
struct PresetAvatar: Identifiable, Codable, Sendable, Hashable {
	let id: String
	let name: String
	let filename: String
	let rarity: String?
	let appellation: String?
	let profession: String?
	let subProfessionID: String?
	let nationID: String?
	let groupID: String?
	let teamID: String?
	let tagList: [String]

	init(
		id: String,
		name: String,
		filename: String,
		rarity: String?,
		appellation: String? = nil,
		profession: String? = nil,
		subProfessionID: String? = nil,
		nationID: String? = nil,
		groupID: String? = nil,
		teamID: String? = nil,
		tagList: [String] = []
	) {
		self.id = id
		self.name = name
		self.filename = filename
		self.rarity = rarity
		self.appellation = appellation
		self.profession = profession
		self.subProfessionID = subProfessionID
		self.nationID = nationID
		self.groupID = groupID
		self.teamID = teamID
		self.tagList = tagList
	}

	/// Search input includes stable upstream metadata, while the identifier stays presentation-free.
	var searchableValues: [String] {
		[
			id, name, appellation, profession, subProfessionID, nationID, groupID, teamID, rarity,
		]
		.compactMap { $0 } + tagList
	}

	var url: URL {
		URL(
			string:
				"https://cdn.jsdelivr.net/gh/PuppiizSunniiz/Arknight-Images@main/avatars/"
		)!.appending(path: "\(id).png")
	}
}

/// Official high-resolution wallpaper entry.
struct PresetWallpaper: Identifiable, Codable, Sendable, Hashable {
	let id: String
	let title: String
	let fallbackOrdinal: Int?
	let url: URL
	let thumbnailURL: URL?
	let author: String?
	let description: String?

	init(
		id: String,
		title: String,
		fallbackOrdinal: Int?,
		url: URL,
		thumbnailURL: URL?,
		author: String? = nil,
		description: String? = nil
	) {
		self.id = id
		self.title = title
		self.fallbackOrdinal = fallbackOrdinal
		self.url = url
		self.thumbnailURL = thumbnailURL
		self.author = author
		self.description = description
	}

	var displayTitle: String {
		fallbackOrdinal.map { L10n.string(CustomizationStrings.wallpaperFallbackTitle($0)) }
			?? title
	}

	var category: WallpaperCategory { WallpaperCategory(title: title) }
}

enum WallpaperCategory: String, CaseIterable, Identifiable, Sendable {
	case story
	case commemorative
	case celebration
	case holiday

	var id: Self { self }

	init(title: String) {
		if Self.holidayKeywords.contains(where: title.localizedStandardContains) {
			self = .holiday
		} else if Self.celebrationKeywords.contains(where: title.localizedStandardContains) {
			self = .celebration
		} else if title.localizedStandardContains("Commemorative Wallpaper") {
			self = .commemorative
		} else {
			self = .story
		}
	}

	private static let celebrationKeywords = ["Anniver", "Celebration", "Livestream"]
	private static let holidayKeywords = [
		"Christmas", "Halloween", "Thanksgiving", "Valentine's Day", "Easter",
		"Chinese New Year", "April Fool's Day", "Children's Day", "New Year",
	]
}

struct WallpaperTagManifest: Decodable, Sendable {
	let schemaVersion: Int
	let tags: [String: [String]]
}

enum WallpaperTagCatalog {
	static let shared: [String: [String]] = load()

	static func tags(for wallpaperID: String) -> [String] {
		if let tags = shared[wallpaperID] { return tags }
		guard wallpaperID.hasPrefix("wp_") else { return [] }
		return shared["global-" + String(wallpaperID.dropFirst(3))] ?? []
	}

	private static func load() -> [String: [String]] {
		// `WallpaperTags.json` is a `.copy()` package resource, so the packaged app copies it
		// flat into `Contents/Resources` rather than into the SwiftPM `Bundle.module` bundle —
		// the same pattern `AppIconRenderer+Avatars` uses for its own `.copy()` resources.
		guard
			let url = Bundle.main.url(forResource: "WallpaperTags", withExtension: "json")
				?? AppResourceBundle.bundle.url(forResource: "WallpaperTags", withExtension: "json"),
			let data = try? Data(contentsOf: url),
			let manifest = try? JSONDecoder().decode(WallpaperTagManifest.self, from: data),
			manifest.schemaVersion == 1
		else { return [:] }
		return manifest.tags
	}
}

/// Decodes identity fields from `character_table.json`.
struct RawCharacterEntry: Decodable {
	let name: String
	let isNotObtainable: Bool?
	let rarity: String?
	let appellation: String?
	let profession: String?
	let subProfessionID: String?
	let nationID: String?
	let groupID: String?
	let teamID: String?
	let tagList: [String]

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		name = try container.decode(String.self, forKey: .name)
		isNotObtainable = try container.decodeIfPresent(Bool.self, forKey: .isNotObtainable)
		if let numericRarity = try? container.decode(Int.self, forKey: .rarity) {
			rarity = "TIER_\(numericRarity + 1)"
		} else {
			rarity = try container.decodeIfPresent(String.self, forKey: .rarity)
		}
		appellation = try container.decodeIfPresent(String.self, forKey: .appellation)
		profession = try container.decodeIfPresent(String.self, forKey: .profession)
		subProfessionID = try container.decodeIfPresent(String.self, forKey: .subProfessionID)
		nationID = try container.decodeIfPresent(String.self, forKey: .nationID)
		groupID = try container.decodeIfPresent(String.self, forKey: .groupID)
		teamID = try container.decodeIfPresent(String.self, forKey: .teamID)
		tagList = try container.decodeIfPresent([String].self, forKey: .tagList) ?? []
	}

	private enum CodingKeys: String, CodingKey {
		case name, isNotObtainable, rarity, appellation, profession, tagList
		case subProfessionID = "subProfessionId"
		case nationID = "nationId"
		case groupID = "groupId"
		case teamID = "teamId"
	}
}

/// Tolerant decoders for Yostar's Fan Kit gallery API (handles mixed String/Int types and key variants).
struct YostarGalleryResponse: Decodable {
	let data: YostarGalleryData?
}

struct YostarGalleryData: Decodable {
	let rows: [YostarGalleryRow]?
	let list: [YostarGalleryRow]?
}

struct YostarGalleryRow: Decodable {
	let id: Int?
	let title: String?
	let author: String?
	let description: String?
	let image1: String?
	let smallImage: String?

	enum CodingKeys: String, CodingKey {
		case id
		case title
		case author
		case description
		case image1
		case smallImage
		case smallImageSnakeCase = "small_image"
		case image
	}

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		if let numericID = try? container.decode(Int.self, forKey: .id) {
			id = numericID
		} else if let stringID = try? container.decode(String.self, forKey: .id) {
			id = Int(stringID.trimmingCharacters(in: .whitespacesAndNewlines))
		} else {
			id = nil
		}
		title = Self.trimmed(decodeStringOrInt(from: container, forKey: .title))
		author = Self.trimmed(decodeStringOrInt(from: container, forKey: .author))
		description = Self.trimmed(decodeStringOrInt(from: container, forKey: .description))
		let image1FromImage1 = decodeStringOrInt(from: container, forKey: .image1)
		let image1FromImage = decodeStringOrInt(from: container, forKey: .image)
		image1 = image1FromImage1 ?? image1FromImage

		let smallImageFromSmallImage = decodeStringOrInt(
			from: container,
			forKey: .smallImage
		)
		let smallImageFromSnakeCase = decodeStringOrInt(
			from: container,
			forKey: .smallImageSnakeCase
		)
		smallImage = smallImageFromSmallImage ?? smallImageFromSnakeCase ?? image1
	}

	private static func trimmed(_ value: String?) -> String? {
		guard let value else { return nil }
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}
}

private func decodeStringOrInt(
	from container: KeyedDecodingContainer<YostarGalleryRow.CodingKeys>,
	forKey key: YostarGalleryRow.CodingKeys
) -> String? {
	if let value = try? container.decodeIfPresent(String.self, forKey: key) {
		return value
	}
	if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
		return String(value)
	}
	// Older Fankit gallery entries wrap the image URL in a single-element array
	// instead of returning it as a plain string.
	if let values = try? container.decodeIfPresent([String].self, forKey: key) {
		return values.first
	}
	return nil
}
