// SPDX-License-Identifier: MPL-2.0

//
// GeneratedStringSymbols_Customization.swift
// Auto-Generated symbols for localized strings defined in “Customization.xcstrings”.
//

import Foundation

#if SWIFT_PACKAGE
	private nonisolated let resourceBundle = AppResourceBundle.bundle
	@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
	private nonisolated let resourceBundleDescription = LocalizedStringResource.BundleDescription
		.atURL(resourceBundle.bundleURL)
#else

	private class ResourceBundleClass {}
	@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
	private nonisolated let resourceBundleDescription = LocalizedStringResource.BundleDescription
		.forClass(ResourceBundleClass.self)
#endif

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
nonisolated extension LocalizedStringResource {
	/// Namespace for strings in file “Customization.xcstrings”.
	enum Customization {
		/**
		 Open generated launcher and game icon style preview

		 Localized string for key “customization.gallery.action.previewStyles” in table “Customization.xcstrings”.
		 */
		static var customizationGalleryActionPreviewStyles: LocalizedStringResource {
			LocalizedStringResource(
				"customization.gallery.action.previewStyles", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Progress state while applying a selected gallery item

		 Localized string for key “customization.gallery.applying” in table “Customization.xcstrings”.
		 */
		static var customizationGalleryApplying: LocalizedStringResource {
			LocalizedStringResource(
				"customization.gallery.applying", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Empty state when no artwork matches the gallery search

		 Localized string for key “customization.gallery.artwork.empty” in table “Customization.xcstrings”.
		 */
		static var customizationGalleryArtworkEmpty: LocalizedStringResource {
			LocalizedStringResource(
				"customization.gallery.artwork.empty", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Loading state while fetching official wallpaper choices

		 Localized string for key “customization.gallery.artwork.loading” in table “Customization.xcstrings”.
		 */
		static var customizationGalleryArtworkLoading: LocalizedStringResource {
			LocalizedStringResource(
				"customization.gallery.artwork.loading", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Artwork gallery search field placeholder

		 Localized string for key “customization.gallery.artwork.searchPlaceholder” in table “Customization.xcstrings”.
		 */
		static var customizationGalleryArtworkSearchPlaceholder: LocalizedStringResource {
			LocalizedStringResource(
				"customization.gallery.artwork.searchPlaceholder", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Artwork gallery explanation

		 Localized string for key “customization.gallery.artwork.subtitle” in table “Customization.xcstrings”.
		 */
		static var customizationGalleryArtworkSubtitle: LocalizedStringResource {
			LocalizedStringResource(
				"customization.gallery.artwork.subtitle", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Artwork gallery title

		 Localized string for key “customization.gallery.artwork.title” in table “Customization.xcstrings”.
		 */
		static var customizationGalleryArtworkTitle: LocalizedStringResource {
			LocalizedStringResource(
				"customization.gallery.artwork.title", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Accessibility help for applying an operator to the launcher and game icons; operator name is supplied content

		 Localized string for key “customization.gallery.operator.applyHelp” in table “Customization.xcstrings”.
		 */
		static func customizationGalleryOperatorApplyHelp(_ arg1: String) -> LocalizedStringResource
		{
			LocalizedStringResource(
				"customization.gallery.operator.applyHelp", defaultValue: "\(arg1)",
				table: "Customization", bundle: resourceBundleDescription)
		}

		/**
		 Empty state when no operators match the gallery search

		 Localized string for key “customization.gallery.operator.empty” in table “Customization.xcstrings”.
		 */
		static var customizationGalleryOperatorEmpty: LocalizedStringResource {
			LocalizedStringResource(
				"customization.gallery.operator.empty", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Loading state while fetching operator choices

		 Localized string for key “customization.gallery.operator.loading” in table “Customization.xcstrings”.
		 */
		static var customizationGalleryOperatorLoading: LocalizedStringResource {
			LocalizedStringResource(
				"customization.gallery.operator.loading", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Operator gallery search field placeholder

		 Localized string for key “customization.gallery.operator.searchPlaceholder” in table “Customization.xcstrings”.
		 */
		static var customizationGalleryOperatorSearchPlaceholder: LocalizedStringResource {
			LocalizedStringResource(
				"customization.gallery.operator.searchPlaceholder", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Operator gallery explanation

		 Localized string for key “customization.gallery.operator.subtitle” in table “Customization.xcstrings”.
		 */
		static var customizationGalleryOperatorSubtitle: LocalizedStringResource {
			LocalizedStringResource(
				"customization.gallery.operator.subtitle", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Operator gallery title

		 Localized string for key “customization.gallery.operator.title” in table “Customization.xcstrings”.
		 */
		static var customizationGalleryOperatorTitle: LocalizedStringResource {
			LocalizedStringResource(
				"customization.gallery.operator.title", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Accessibility label for the current gallery search field

		 Localized string for key “customization.gallery.search.label” in table “Customization.xcstrings”.
		 */
		static var customizationGallerySearchLabel: LocalizedStringResource {
			LocalizedStringResource(
				"customization.gallery.search.label", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Accessibility help for applying a wallpaper; wallpaper title is supplied content

		 Localized string for key “customization.gallery.wallpaper.applyHelp” in table “Customization.xcstrings”.
		 */
		static func customizationGalleryWallpaperApplyHelp(_ arg1: String)
			-> LocalizedStringResource
		{
			LocalizedStringResource(
				"customization.gallery.wallpaper.applyHelp", defaultValue: "\(arg1)",
				table: "Customization", bundle: resourceBundleDescription)
		}

		/**
		 Game icon style explanation

		 Localized string for key “customization.iconPreview.game.detail” in table “Customization.xcstrings”.
		 */
		static var customizationIconPreviewGameDetail: LocalizedStringResource {
			LocalizedStringResource(
				"customization.iconPreview.game.detail", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Game icon style label

		 Localized string for key “customization.iconPreview.game.title” in table “Customization.xcstrings”.
		 */
		static var customizationIconPreviewGameTitle: LocalizedStringResource {
			LocalizedStringResource(
				"customization.iconPreview.game.title", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Launcher icon style explanation

		 Localized string for key “customization.iconPreview.launcher.detail” in table “Customization.xcstrings”.
		 */
		static var customizationIconPreviewLauncherDetail: LocalizedStringResource {
			LocalizedStringResource(
				"customization.iconPreview.launcher.detail", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Launcher icon style label

		 Localized string for key “customization.iconPreview.launcher.title” in table “Customization.xcstrings”.
		 */
		static var customizationIconPreviewLauncherTitle: LocalizedStringResource {
			LocalizedStringResource(
				"customization.iconPreview.launcher.title", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Loading state while rendering the generated icon previews

		 Localized string for key “customization.iconPreview.loading” in table “Customization.xcstrings”.
		 */
		static var customizationIconPreviewLoading: LocalizedStringResource {
			LocalizedStringResource(
				"customization.iconPreview.loading", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Accessibility label for the paired launcher and game icon preview

		 Localized string for key “customization.iconPreview.pair.accessibilityLabel” in table “Customization.xcstrings”.
		 */
		static var customizationIconPreviewPairAccessibilityLabel: LocalizedStringResource {
			LocalizedStringResource(
				"customization.iconPreview.pair.accessibilityLabel", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Accessibility label when generated icon previews cannot be rendered

		 Localized string for key “customization.iconPreview.pair.unavailable” in table “Customization.xcstrings”.
		 */
		static var customizationIconPreviewPairUnavailable: LocalizedStringResource {
			LocalizedStringResource(
				"customization.iconPreview.pair.unavailable", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Generated icon preview explanation

		 Localized string for key “customization.iconPreview.subtitle” in table “Customization.xcstrings”.
		 */
		static var customizationIconPreviewSubtitle: LocalizedStringResource {
			LocalizedStringResource(
				"customization.iconPreview.subtitle", table: "Customization",
				bundle: resourceBundleDescription)
		}

		/**
		 Generated icon preview title

		 Localized string for key “customization.iconPreview.title” in table “Customization.xcstrings”.
		 */
		static var customizationIconPreviewTitle: LocalizedStringResource {
			LocalizedStringResource(
				"customization.iconPreview.title", table: "Customization",
				bundle: resourceBundleDescription)
		}
	}
}
