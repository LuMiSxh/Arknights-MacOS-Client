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
	let fallbackOrdinal: Int?
	let url: URL
	let thumbnailURL: URL?

	var displayTitle: String {
		fallbackOrdinal.map { L10n.string(CustomizationStrings.wallpaperFallbackTitle($0)) }
			?? title
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
	let title: String?
	let image1: String?
	let smallImage: String?

	enum CodingKeys: String, CodingKey {
		case title
		case image1
		case smallImage
		case smallImageSnakeCase = "small_image"
		case image
	}

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
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
