// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

private final class FailingCacheEnumerationFileManager: FileManager {
	override func contentsOfDirectory(
		at url: URL,
		includingPropertiesForKeys keys: [URLResourceKey]? = nil,
		options mask: FileManager.DirectoryEnumerationOptions = []
	) throws -> [URL] {
		throw CocoaError(.fileReadNoPermission)
	}
}

@Test
func appPathsUseStandardInjectedDirectories() throws {
	let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
	let support = root.appending(path: "Application Support")
	let caches = root.appending(path: "Caches")
	let library = root.appending(path: "Library")
	let paths = AppPaths(
		applicationSupportDirectory: support,
		cachesDirectory: caches,
		libraryDirectory: library
	)
	let id = AppPaths.bundleIdentifier
	let logs = "Logs/\(id)"

	let rows: [(URL, URL)] = [
		(paths.applicationSupportRoot, support.appending(path: id)),
		(paths.cacheRoot, caches.appending(path: id)),
		(paths.logRoot, library.appending(path: logs)),
		(paths.gameInstall(for: .global), support.appending(path: "\(id)/Yostar/Global")),
		(paths.gameInstall(for: .japan), support.appending(path: "\(id)/Yostar/Japan")),
		(paths.gameInstall(for: .korea), support.appending(path: "\(id)/Yostar/Korea")),
		(paths.gameInstall(for: .china), support.appending(path: "\(id)/Hypergryph/China")),
		(
			paths.gameInstall(for: .chinaBilibili),
			support.appending(path: "\(id)/Hypergryph/China-Bilibili")
		),
		(paths.gameInstall(for: .taiwan), support.appending(path: "\(id)/Gryphline/Taiwan")),
		(paths.winePrefix, support.appending(path: "\(id)/Yostar/Prefix")),
		(paths.chinaWinePrefix, support.appending(path: "\(id)/Hypergryph/Prefix")),
		(paths.gryphlineWinePrefix, support.appending(path: "\(id)/Gryphline/Prefix")),
		(paths.yostarLogFile, library.appending(path: "\(logs)/arknights-yostar.log")),
		(
			paths.publisherLogFile(for: .hypergryph),
			library.appending(path: "\(logs)/arknights-hypergryph.log")
		),
		(
			paths.publisherLogFile(for: .gryphline),
			library.appending(path: "\(logs)/arknights-gryphline.log")
		),
		(paths.launcherLogFile, library.appending(path: "\(logs)/launcher.log")),
		(paths.artworkCache, caches.appending(path: "\(id)/Artwork/Downloaded")),
		(paths.presetGalleryCache, caches.appending(path: "\(id)/PresetGallery")),
		(paths.customArtwork, support.appending(path: "\(id)/Artwork/Custom/artwork")),
		(paths.customAppIcon, support.appending(path: "\(id)/Artwork/Custom/app-icon")),
		(paths.customGameIcon, support.appending(path: "\(id)/Artwork/Custom/game-icon")),
		(
			paths.operatorPresetAvatar,
			support.appending(path: "\(id)/Artwork/Custom/operator-avatar-source")
		),
		(
			paths.playtimeStatistics,
			support.appending(path: "\(id)/\(AppConstants.Playtime.statisticsFilename)")
		),
	]
	for (actual, expected) in rows {
		#expect(actual.standardizedFileURL.path == expected.standardizedFileURL.path)
	}
	#expect(paths.winePrefix(for: .chinaBilibili) == paths.winePrefix(for: .china))
	#expect(paths.winePrefix(for: .taiwan) == paths.gryphlineWinePrefix)

	let missingPrefix = root.appending(path: "MissingCacheUsers", directoryHint: .isDirectory)
	#expect(try AppPaths.gameCacheDirectories(winePrefix: missingPrefix).isEmpty)
	#expect(throws: AppPathsError.self) {
		try AppPaths.gameCacheDirectories(
			winePrefix: root.appending(path: "Unreadable", directoryHint: .isDirectory),
			fileManager: FailingCacheEnumerationFileManager()
		)
	}
}
