// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Third-party content the preset gallery loads at runtime.
///
/// This file is the only place that names these upstream locations. Size limits live in
/// `AppConstants.Presets`. Every source degrades gracefully: a failed fetch keeps the cached
/// catalog, or the curated list for avatars, and never blocks the launcher.
///
/// TODO(pin): The community mirrors below track `main` because the repository cannot determine a
/// trusted commit offline. Replace `main` with a reviewed commit SHA, then bump it on purpose.
enum PresetRemoteSources {
	/// Operator catalog (`character_table.json`) from the community GameData mirror.
	/// Bound: `AppConstants.Presets.characterCatalogMaximumBytes`. Fallback: curated avatars.
	static let characterTable = URL(
		string:
			"https://cdn.jsdelivr.net/gh/Kengxxiao/ArknightsGameData_YoStar@main/en_US/gamedata/excel/character_table.json"
	)!

	/// Avatar image hosts in preference order. The first entry is a CDN. The others are raw
	/// GitHub mirrors that `PresetCatalogService.imageData` tries when the CDN fails.
	static let primaryAvatarDirectory = URL(
		string: "https://cdn.jsdelivr.net/gh/PuppiizSunniiz/Arknight-Images@main/avatars/"
	)!
	static let fallbackAvatarDirectories = [
		URL(
			string: "https://raw.githubusercontent.com/PuppiizSunniiz/Arknight-Images/main/avatars/"
		)!,
		URL(
			string: "https://raw.githubusercontent.com/Aceship/Arknight-Images/main/avatars/"
		)!,
	]
	static let primaryAvatarHost = "cdn.jsdelivr.net"

	/// Yostar Fankit gallery list. Bound: `AppConstants.Presets.wallpaperCatalogMaximumBytes`.
	/// Fallback: the cached catalog, otherwise an empty gallery.
	static func wallpaperGalleryPage(index: Int, size: Int) -> URL? {
		URL(
			string:
				"https://www.arknights.global/api/resource/gallery/list?index=\(index)&size=\(size)"
		)
	}
}
