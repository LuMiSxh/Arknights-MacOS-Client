// SPDX-License-Identifier: MPL-2.0

import Foundation

enum CustomizationStrings {
	static let previewStyles = LocalizedStringResource.Customization
		.customizationGalleryActionPreviewStyles
	static let applying = LocalizedStringResource.Customization.customizationGalleryApplying
	static let artworkEmpty = LocalizedStringResource.Customization.customizationGalleryArtworkEmpty
	static let artworkLoading = LocalizedStringResource.Customization
		.customizationGalleryArtworkLoading
	static let artworkSearchPlaceholder = LocalizedStringResource.Customization
		.customizationGalleryArtworkSearchPlaceholder
	static let artworkSubtitle = LocalizedStringResource.Customization
		.customizationGalleryArtworkSubtitle
	static let artworkTitle = LocalizedStringResource.Customization.customizationGalleryArtworkTitle
	static let operatorEmpty = LocalizedStringResource.Customization
		.customizationGalleryOperatorEmpty
	static let operatorLoading = LocalizedStringResource.Customization
		.customizationGalleryOperatorLoading
	static let operatorSearchPlaceholder = LocalizedStringResource.Customization
		.customizationGalleryOperatorSearchPlaceholder
	static let operatorSubtitle = LocalizedStringResource.Customization
		.customizationGalleryOperatorSubtitle
	static let operatorTitle = LocalizedStringResource.Customization
		.customizationGalleryOperatorTitle
	static let searchLabel = LocalizedStringResource.Customization.customizationGallerySearchLabel
	static let searchClear = LocalizedStringResource.Customization.customizationGallerySearchClear
	static let searchSuggestionSelect = LocalizedStringResource.Customization
		.customizationGallerySearchSuggestionSelect
	static let wallpaperFilterAll = LocalizedStringResource.Customization
		.customizationGalleryWallpaperFilterAll
	static let wallpaperFilterLabel = LocalizedStringResource.Customization
		.customizationGalleryWallpaperFilterLabel
	static let gameStyleDetail = LocalizedStringResource.Customization
		.customizationIconPreviewGameDetail
	static let gameStyleTitle = LocalizedStringResource.Customization
		.customizationIconPreviewGameTitle
	static let launcherStyleDetail = LocalizedStringResource.Customization
		.customizationIconPreviewLauncherDetail
	static let launcherStyleTitle = LocalizedStringResource.Customization
		.customizationIconPreviewLauncherTitle
	static let iconPreviewLoading = LocalizedStringResource.Customization
		.customizationIconPreviewLoading
	static let iconPreviewPairAccessibilityLabel = LocalizedStringResource.Customization
		.customizationIconPreviewPairAccessibilityLabel
	static let iconPreviewUnavailable = LocalizedStringResource.Customization
		.customizationIconPreviewPairUnavailable
	static let iconPreviewSubtitle = LocalizedStringResource.Customization
		.customizationIconPreviewSubtitle
	static let iconPreviewTitle = LocalizedStringResource.Customization
		.customizationIconPreviewTitle

	static func operatorApplyHelp(_ name: String) -> LocalizedStringResource {
		.Customization.customizationGalleryOperatorApplyHelp(name)
	}

	static func wallpaperApplyHelp(_ title: String) -> LocalizedStringResource {
		.Customization.customizationGalleryWallpaperApplyHelp(title)
	}

	static func searchRemoveTag(_ tag: String) -> LocalizedStringResource {
		.Customization.customizationGallerySearchRemoveTag(tag)
	}

	static func wallpaperFallbackTitle(_ number: Int) -> LocalizedStringResource {
		.Customization.customizationGalleryWallpaperFallbackTitle(number)
	}

	static func wallpaperCategory(_ category: WallpaperCategory) -> LocalizedStringResource {
		switch category {
		case .story: .Customization.customizationGalleryWallpaperTypeStory
		case .commemorative: .Customization.customizationGalleryWallpaperTypeCommemorative
		case .celebration: .Customization.customizationGalleryWallpaperTypeCelebration
		case .holiday: .Customization.customizationGalleryWallpaperTypeHoliday
		}
	}
}
