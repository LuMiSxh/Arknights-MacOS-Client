// SPDX-License-Identifier: MPL-2.0

import Foundation

struct PresetGallerySearchQuery: Equatable, Sendable {
	let destination: PresetGalleryDestination
	let searchText: String
	let committedTags: [String]
	let selectedCategory: WallpaperCategory?
	let catalogRevision: Int
	let avatarRevision: Int
	let catalogReady: Bool
}

struct PresetGallerySearchResults: Equatable, Sendable {
	let filteredAvatars: [PresetAvatar]
	let filteredWallpapers: [PresetWallpaper]
	let wallpaperCategoryCounts: [WallpaperCategory?: Int]
	let wallpaperTerms: [String]
	let operatorCounts: [OperatorArtCount]

	static let empty = Self(
		filteredAvatars: [],
		filteredWallpapers: [],
		wallpaperCategoryCounts: [:],
		wallpaperTerms: [],
		operatorCounts: []
	)
}
