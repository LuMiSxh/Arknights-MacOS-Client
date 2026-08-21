// SPDX-License-Identifier: MPL-2.0

import Foundation

/// DXMT's shader cache and the embedded browser's cache both rebuild automatically, so
/// clearing them only costs a slower next launch, not lost state.
enum GameCacheCleaner {
	static func cacheDirectories(
		winePrefix: URL,
		fileManager: FileManager = .default
	) -> [URL] {
		var directories = [
			winePrefix.appending(path: "home/.cache/dxmt", directoryHint: .isDirectory)
		]
		let usersDirectory = winePrefix.appending(
			path: "drive_c/users", directoryHint: .isDirectory)
		if let entries = try? fileManager.contentsOfDirectory(
			at: usersDirectory,
			includingPropertiesForKeys: nil
		) {
			// Enumerated rather than a fixed "crossover" username: CrossOver-derived Wine
			// builds have historically used both a fixed profile name and NSUserName(),
			// so an upgraded prefix could have either.
			directories += entries.map {
				$0.appending(path: "AppData/Local/cache", directoryHint: .isDirectory)
			}
		}
		return directories.filter { fileManager.fileExists(atPath: $0.path) }
	}

	static func totalSize(winePrefix: URL, fileManager: FileManager = .default) -> Int64 {
		cacheDirectories(winePrefix: winePrefix, fileManager: fileManager).reduce(Int64(0)) {
			$0 + directorySize(at: $1, fileManager: fileManager)
		}
	}

	static func clear(winePrefix: URL, fileManager: FileManager = .default) throws {
		for directory in cacheDirectories(winePrefix: winePrefix, fileManager: fileManager) {
			try fileManager.removeItem(at: directory)
		}
	}

	private static func directorySize(at url: URL, fileManager: FileManager) -> Int64 {
		guard
			let enumerator = fileManager.enumerator(
				at: url,
				includingPropertiesForKeys: [.fileSizeKey]
			)
		else { return 0 }
		var total: Int64 = 0
		for case let fileURL as URL in enumerator {
			total += Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
		}
		return total
	}
}
