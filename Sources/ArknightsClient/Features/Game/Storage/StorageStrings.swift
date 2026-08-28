// SPDX-License-Identifier: MPL-2.0

import Foundation

enum StorageStrings {
	static let title = LocalizedStringResource.Settings.settingsStorageTitle
	static let subtitle = LocalizedStringResource.Settings.settingsStorageSubtitle
	static let installations = LocalizedStringResource.Settings.settingsStorageSectionInstallations
	static let shared = LocalizedStringResource.Settings.settingsStorageSectionShared
	static let caches = LocalizedStringResource.Settings.settingsStorageSectionCaches
	static let unavailable = LocalizedStringResource.Settings.settingsStorageCommonUnavailable
	static let refresh = LocalizedStringResource.Settings.settingsStorageActionRefresh
	static let clearCaches = LocalizedStringResource.Settings.settingsStorageActionClearCaches
	static let clearGalleryCache =
		LocalizedStringResource.Settings.settingsStorageActionClearGalleryCache
	static let compatibilityRuntime =
		LocalizedStringResource.Settings.settingsStorageCategoryCompatibilityRuntime
	static let dxmtCache = LocalizedStringResource.Settings.settingsStorageCategoryDxmtCache
	static let browserCache = LocalizedStringResource.Settings.settingsStorageCategoryBrowserCache

	static func copy() -> StorageOverviewCopy {
		StorageOverviewCopy(
			title: L10n.string(title),
			subtitle: L10n.string(subtitle),
			installationsTitle: L10n.string(installations),
			sharedTitle: L10n.string(shared),
			cachesTitle: L10n.string(caches),
			logsTitle: L10n.string(SettingsStrings.logs),
			calculating: L10n.string(SettingsStrings.calculating),
			unavailable: L10n.string(unavailable),
			clearCaches: L10n.string(clearCaches),
			clearGalleryCache: L10n.string(clearGalleryCache),
			showLogs: L10n.string(SettingsStrings.showLogs),
			categoryTitle: categoryTitle,
			categoryDetail: categoryDetail
		)
	}

	private static func categoryTitle(_ category: StorageCategory) -> String {
		switch category {
		case .game(let region): region.localizedDisplayName
		case .winePrefix: L10n.string(SettingsStrings.winePrefix)
		case .compatibilityRuntime: L10n.string(compatibilityRuntime)
		case .dxmtCache: L10n.string(dxmtCache)
		case .browserCache: L10n.string(browserCache)
		case .galleryCache: L10n.string(SettingsStrings.cacheGallery)
		case .logs: L10n.string(SettingsStrings.logs)
		}
	}

	private static func categoryDetail(_ category: StorageCategory, _ size: String) -> String {
		switch category {
		case .game: L10n.string(.Settings.settingsStorageCategoryGameDetail(size))
		case .winePrefix: L10n.string(.Settings.settingsStorageCategoryWinePrefixDetail(size))
		case .compatibilityRuntime:
			L10n.string(.Settings.settingsStorageCategoryCompatibilityRuntimeDetail(size))
		case .dxmtCache: L10n.string(.Settings.settingsStorageCategoryDxmtCacheDetail(size))
		case .browserCache: L10n.string(.Settings.settingsStorageCategoryBrowserCacheDetail(size))
		case .galleryCache: L10n.string(SettingsStrings.cacheGalleryDetail(size))
		case .logs: L10n.string(.Settings.settingsStorageCategoryLogsDetail(size))
		}
	}
}
