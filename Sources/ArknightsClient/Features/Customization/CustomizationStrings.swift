// SPDX-License-Identifier: MPL-2.0

enum CustomizationStrings {
	static let previewStyles = "Preview Styles"
	static let applying = "Applying…"
	static let artworkEmpty = "No matching artwork"
	static let artworkLoading = "Loading official wallpapers…"
	static let artworkSearchPlaceholder = "Search artwork…"
	static let artworkSubtitle = "Choose a background for the launcher."
	static let artworkTitle = "Artwork Gallery"
	static let operatorEmpty = "No matching operators"
	static let operatorLoading = "Loading operators…"
	static let operatorSearchPlaceholder = "Search operators…"
	static let operatorSubtitle = "Choose one operator for both Dock icons."
	static let operatorTitle = "Choose an Operator"
	static let searchLabel = "Search gallery"
	static let searchClear = "Clear search"
	static let searchSuggestionSelect = "Select and use this exact title in the search"
	static let wallpaperFilterAll = "All Types"
	static let wallpaperFilterLabel = "Wallpaper type"
	static let gameStyleDetail = "Original Arknights style"
	static let gameStyleTitle = "Game"
	static let launcherStyleDetail = "Launcher style"
	static let launcherStyleTitle = "Launcher"
	static let iconPreviewLoading = "Loading preview…"
	static let iconPreviewPairAccessibilityLabel = "Launcher and game icon previews"
	static let iconPreviewUnavailable = "Icon previews unavailable"
	static let iconPreviewSubtitle = "Your operator is applied to both icons."
	static let iconPreviewTitle = "Generated Icon Styles"

	static func operatorApplyHelp(_ name: String) -> String {
		"Use \(name) for both Dock icons"
	}

	static func wallpaperApplyHelp(_ title: String) -> String {
		"Use \(title) as the launcher background"
	}

	static func searchRemoveTag(_ tag: String) -> String {
		"Remove \(tag) tag"
	}

	static func wallpaperFallbackTitle(_ number: Int) -> String {
		"Wallpaper \(number)"
	}

	static func wallpaperCategory(_ category: WallpaperCategory) -> String {
		switch category {
		case .story: "Story"
		case .commemorative: "Commemorative"
		case .celebration: "Celebration"
		case .holiday: "Holiday"
		}
	}

	static func wallpaperFilterOption(_ title: String, count: Int) -> String {
		"\(title) (\(count))"
	}

	static let wallpaperFilterOperators = "Operators"

	static func wallpaperHoverArtist(_ name: String) -> String {
		"Artist: \(name)"
	}

	static func wallpaperHoverTags(_ tags: String) -> String {
		"Tags: \(tags)"
	}
}
