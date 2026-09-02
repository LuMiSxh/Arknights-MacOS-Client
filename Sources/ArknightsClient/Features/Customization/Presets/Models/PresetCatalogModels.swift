// SPDX-License-Identifier: MPL-2.0

import Foundation

/// A lightweight operator avatar representation for the gallery.
struct PresetAvatar: Identifiable, Codable, Sendable, Hashable {
	let id: String
	let name: String
	let filename: String
	let rarity: String?

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
	let url: URL
	let thumbnailURL: URL?

	var category: WallpaperCategory { WallpaperCategory(title: title) }
}

/// Broad grouping for the gallery's type filter, derived entirely from a wallpaper's
/// official title rather than curated data — Yostar's own titles already follow
/// stable conventions ("X Followers Commemorative Wallpaper", "20XX Christmas",
/// "Nth Anniversary Celebration") that are reliable enough to classify by.
enum WallpaperCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
	case story = "Story"
	case commemorative = "Commemorative"
	case celebration = "Celebration"
	case holiday = "Holiday"

	var id: String { rawValue }

	init(title: String) {
		if Self.holidayKeywords.contains(where: { title.localizedStandardContains($0) }) {
			self = .holiday
		} else if Self.celebrationKeywords.contains(where: {
			title.localizedStandardContains($0)
		}) {
			self = .celebration
		} else if title.localizedStandardContains("Commemorative Wallpaper") {
			self = .commemorative
		} else {
			self = .story
		}
	}

	// Checked before "Commemorative Wallpaper" since a few titles (e.g. "5.5th
	// Livestream Commemorative Wallpaper") contain both — those are anniversary
	// content first, not a follower/subscriber milestone.
	private static let celebrationKeywords = [
		// Matches "Anniversary" and Yostar's own "Anniverary" typo alike.
		"Anniver", "Celebration", "Livestream",
	]
	private static let holidayKeywords = [
		"Christmas", "Halloween", "Thanksgiving", "Valentine's Day", "Easter",
		"Chinese New Year", "April Fool's Day", "Children's Day", "New Year",
	]
}

/// A community/maintainer-curated set of search tags for a wallpaper, keyed by its stable
/// Fankit gallery ID (see `WallpaperTags.json`). Populated separately from the untagged-wallpaper
/// GitHub issue workflow, so it is intentionally decoupled from `PresetWallpaper`'s cached wire format.
struct WallpaperTagManifest: Decodable, Sendable {
	let schemaVersion: Int
	let tags: [String: [String]]
}

/// Looks up curated search tags (operator names, factions, events, …) for wallpapers by their
/// stable gallery ID. Falls back to an empty catalog if the bundled manifest is missing or malformed.
enum WallpaperTagCatalog {
	static let shared: [String: [String]] = load()

	static func tags(for wallpaperID: String) -> [String] {
		shared[wallpaperID] ?? []
	}

	private static func load() -> [String: [String]] {
		guard
			let url = Bundle.module.url(
				forResource: "WallpaperTags", withExtension: "json"),
			let data = try? Data(contentsOf: url),
			let manifest = try? JSONDecoder().decode(WallpaperTagManifest.self, from: data)
		else { return [:] }
		return manifest.tags
	}
}

/// Decodes identity fields from `character_table.json`.
struct RawCharacterEntry: Decodable {
	let name: String
	let isNotObtainable: Bool?
	let rarity: String?
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
	let image1: String?
	let smallImage: String?

	enum CodingKeys: String, CodingKey {
		case id
		case title
		case image1
		case smallImage
		case smallImageSnakeCase = "small_image"
		case image
	}

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try? container.decodeIfPresent(Int.self, forKey: .id)
		title = try? container.decodeIfPresent(String.self, forKey: .title)
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
