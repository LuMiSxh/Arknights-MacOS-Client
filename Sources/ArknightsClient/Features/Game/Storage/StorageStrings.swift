// SPDX-License-Identifier: MPL-2.0

enum StorageStrings {
	static let title = "Storage"
	static let subtitle = "Disk usage and targeted cleanup"
	static let installations = "Game Installations"
	static let shared = "Shared Runtime Data"
	static let caches = "Recreatable Caches"
	static let unavailable = "Not present"
	static let refresh = "Refresh"
	static let clearCaches = "Clear Caches"
	static let clearGalleryCache =
		"Clear Gallery Cache"
	static let compatibilityRuntime =
		"Compatibility Runtime"
	static let dxmtCache = "DXMT Shader Cache"
	static let browserCache = "Embedded Browser Data"

	static func copy() -> StorageOverviewCopy {
		StorageOverviewCopy(
			title: title,
			subtitle: subtitle,
			installationsTitle: installations,
			sharedTitle: shared,
			cachesTitle: caches,
			logsTitle: SettingsStrings.logs,
			calculating: SettingsStrings.calculating,
			unavailable: unavailable,
			clearCaches: clearCaches,
			clearGalleryCache: clearGalleryCache,
			showLogs: SettingsStrings.showLogs,
			categoryTitle: categoryTitle,
			categoryDetail: categoryDetail
		)
	}

	private static func categoryTitle(_ category: StorageCategory) -> String {
		switch category {
		case .game(let region): region.displayName
		case .winePrefix: SettingsStrings.winePrefix
		case .compatibilityRuntime: compatibilityRuntime
		case .dxmtCache: dxmtCache
		case .browserCache: browserCache
		case .galleryCache: SettingsStrings.cacheGallery
		case .logs: SettingsStrings.logs
		}
	}

	private static func categoryDetail(_ category: StorageCategory) -> String {
		switch category {
		case .game: "Game files that may require repair or reinstall."
		case .winePrefix: "Shared by the selected client family; contains runtime data and logins."
		case .compatibilityRuntime:
			"Bundled Wine and DXMT components; read-only."
		case .dxmtCache: "Recreated automatically and removed by the cache cleanup action."
		case .browserCache: "Recreated automatically and removed by the cache cleanup action."
		case .galleryCache:
			"Clear cached preset metadata and all downloaded gallery assets (avatars + wallpapers)."
		case .logs: "Launcher and game diagnostics; reveal them in Finder."
		}
	}
}
