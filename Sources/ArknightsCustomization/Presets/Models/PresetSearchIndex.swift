// SPDX-License-Identifier: MPL-2.0

import Foundation
import Synchronization

// Search text and tags for each wallpaper, resolved once per catalog and tag revision.
//
// Gallery searches run on every keystroke. Building this index once avoids re-joining prose,
// re-reading tags, and re-deriving the known tag set for each wallpaper.
struct PresetSearchIndex: Sendable {
	struct Entry: Sendable {
		let wallpaper: PresetWallpaper
		let title: String
		let prose: String
		let fuzzyValues: [String]
		let tags: [String]
	}

	let entries: [Entry]
	let knownTags: Set<String>

	private struct Memo: Sendable {
		let catalog: [String: [String]]
		let wallpapers: [PresetWallpaper]
		let index: PresetSearchIndex
	}

	private static let memo = Mutex<Memo?>(nil)

	// Returns the cached index while both the tag catalog and `wallpapers` are unchanged.
	static func current(for wallpapers: [PresetWallpaper]) -> PresetSearchIndex {
		let catalog = WallpaperTagCatalog.shared
		if let cached = memo.withLock({ $0 }),
			cached.catalog == catalog, cached.wallpapers == wallpapers
		{
			return cached.index
		}
		let index = PresetSearchIndex(wallpapers: wallpapers, catalog: catalog)
		memo.withLock { $0 = Memo(catalog: catalog, wallpapers: wallpapers, index: index) }
		return index
	}

	private init(wallpapers: [PresetWallpaper], catalog: [String: [String]]) {
		entries = wallpapers.map { wallpaper in
			let tags = WallpaperTagCatalog.tags(for: wallpaper.id)
			let optionalValues = [wallpaper.displayTitle, wallpaper.author, wallpaper.description]
			return Entry(
				wallpaper: wallpaper,
				title: wallpaper.displayTitle,
				prose: optionalValues.compactMap { $0 }.joined(separator: " "),
				fuzzyValues: optionalValues.compactMap { $0 } + tags,
				tags: tags
			)
		}
		knownTags = Set(catalog.values.flatMap { $0 }.map(PresetSearch.normalized))
	}
}
