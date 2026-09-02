// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func appPathsUseStandardInjectedDirectories() {
	let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
	let support = root.appending(path: "Application Support")
	let caches = root.appending(path: "Caches")
	let library = root.appending(path: "Library")
	let paths = AppPaths(
		applicationSupportDirectory: support,
		cachesDirectory: caches,
		libraryDirectory: library
	)

	#expect(
		paths.applicationSupportRoot
			== support.appending(path: AppPaths.bundleIdentifier, directoryHint: .isDirectory)
	)
	#expect(
		paths.cacheRoot
			== caches.appending(path: AppPaths.bundleIdentifier, directoryHint: .isDirectory)
	)
	#expect(
		paths.logRoot
			== library.appending(
				path: "Logs/\(AppPaths.bundleIdentifier)",
				directoryHint: .isDirectory
			)
	)
	#expect(
		paths.gameInstall(for: .global)
			== support.appending(
				path: "\(AppPaths.bundleIdentifier)/Games/Arknights-Global",
				directoryHint: .isDirectory
			)
	)
	#expect(
		paths.gameInstall(for: .japan)
			== support.appending(
				path: "\(AppPaths.bundleIdentifier)/Games/Arknights-Japan",
				directoryHint: .isDirectory
			)
	)
	#expect(
		paths.gameInstall(for: .korea)
			== support.appending(
				path: "\(AppPaths.bundleIdentifier)/Games/Arknights-Korea",
				directoryHint: .isDirectory
			)
	)
	#expect(
		paths.winePrefix
			== support.appending(
				path: "\(AppPaths.bundleIdentifier)/Wine/Prefixes/Arknights-Global",
				directoryHint: .isDirectory
			)
	)
	#expect(paths.logFile == library.appending(path: "Logs/\(AppPaths.bundleIdentifier)/wine.log"))
	#expect(
		paths.launcherLogFile
			== library.appending(path: "Logs/\(AppPaths.bundleIdentifier)/launcher.log")
	)
	#expect(
		paths.artworkCache
			== caches.appending(
				path: "\(AppPaths.bundleIdentifier)/Artwork/Downloaded",
				directoryHint: .isDirectory
			)
	)
	#expect(
		paths.presetGalleryCache
			== caches.appending(
				path: "\(AppPaths.bundleIdentifier)/PresetGallery",
				directoryHint: .isDirectory
			)
	)
	#expect(
		paths.customArtwork
			== support.appending(path: "\(AppPaths.bundleIdentifier)/Artwork/Custom/artwork")
	)
	#expect(
		paths.customAppIcon
			== support.appending(path: "\(AppPaths.bundleIdentifier)/Artwork/Custom/app-icon")
	)
	#expect(
		paths.customGameIcon
			== support.appending(path: "\(AppPaths.bundleIdentifier)/Artwork/Custom/game-icon")
	)
	#expect(
		paths.operatorPresetAvatar
			== support.appending(
				path: "\(AppPaths.bundleIdentifier)/Artwork/Custom/operator-avatar-source")
	)
	#expect(
		paths.playtimeStatistics
			== support.appending(
				path: "\(AppPaths.bundleIdentifier)/\(AppConstants.Playtime.statisticsFilename)"
			)
	)
}
