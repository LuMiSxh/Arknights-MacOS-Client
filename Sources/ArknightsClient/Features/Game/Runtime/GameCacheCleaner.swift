// SPDX-License-Identifier: MPL-2.0

import Foundation

/// DXMT's shader cache and the embedded browser's cache both rebuild automatically, so
/// clearing them only costs a slower next launch, not lost state.
enum GameCacheCleaner {
	static func cacheDirectories(
		winePrefix: URL,
		fileManager: FileManager = .default
	) -> [URL] {
		AppPaths.gameCacheDirectories(winePrefix: winePrefix, fileManager: fileManager)
	}

	static func clear(winePrefix: URL, fileManager: FileManager = .default) throws {
		for directory in cacheDirectories(winePrefix: winePrefix, fileManager: fileManager) {
			guard
				AppPaths.isSafeCacheDirectory(
					directory,
					inside: winePrefix.resolvingSymlinksInPath().standardizedFileURL,
					fileManager: fileManager
				)
			else { continue }
			try fileManager.removeItem(at: directory)
		}
	}

}
