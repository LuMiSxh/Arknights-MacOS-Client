// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

// DXMT's shader cache and the embedded browser's cache both rebuild automatically, so
// clearing them only costs a slower next launch, not lost state.
enum GameCacheCleaner {
	static func clear(winePrefix: URL, fileManager: FileManager = .default) throws {
		let directories = try AppPaths.gameCacheDirectories(
			winePrefix: winePrefix, fileManager: fileManager)
		for directory in directories {
			guard
				try AppPaths.isSafeCacheDirectory(
					directory,
					inside: winePrefix.resolvingSymlinksInPath().standardizedFileURL,
					fileManager: fileManager
				)
			else { continue }
			do {
				try fileManager.removeItem(at: directory)
			} catch  where AppPaths.isMissingPathError(error) {
				continue
			}
		}
	}
}
