// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Every standard macOS location this app writes to, rooted under its bundle identifier;
/// the one place these paths are computed, so nothing hardcodes a repository-local path.
struct AppPaths: Sendable {
	static let bundleIdentifier = "com.lumisxh.arknights-client"

	let applicationSupportRoot: URL
	let cacheRoot: URL
	let logRoot: URL
	let winePrefix: URL
	let chinaWinePrefix: URL
	let bundledRuntimeDirectory: URL?

	init(
		fileManager: FileManager = .default,
		applicationSupportDirectory: URL? = nil,
		cachesDirectory: URL? = nil,
		libraryDirectory: URL? = nil,
		resourceDirectory: URL? = Bundle.main.resourceURL
	) {
		let supportDirectory =
			applicationSupportDirectory
			?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		let cachesDirectory =
			cachesDirectory
			?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let libraryDirectory =
			libraryDirectory
			?? fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!

		applicationSupportRoot = supportDirectory.appending(
			path: Self.bundleIdentifier,
			directoryHint: .isDirectory
		)
		cacheRoot = cachesDirectory.appending(
			path: Self.bundleIdentifier,
			directoryHint: .isDirectory
		)
		logRoot =
			libraryDirectory
			.appending(path: "Logs", directoryHint: .isDirectory)
			.appending(path: Self.bundleIdentifier, directoryHint: .isDirectory)
		winePrefix = applicationSupportRoot.appending(
			path: "Wine/Prefixes/Arknights-Global",
			directoryHint: .isDirectory
		)
		chinaWinePrefix = applicationSupportRoot.appending(
			path: "Wine/Prefixes/Arknights-China",
			directoryHint: .isDirectory
		)
		bundledRuntimeDirectory = resourceDirectory?.appending(
			path: "Runtime",
			directoryHint: .isDirectory
		)
	}

	func gameInstall(for region: GameRegion) -> URL {
		applicationSupportRoot.appending(
			path: "Games/\(region.installDirectoryName)",
			directoryHint: .isDirectory
		)
	}

	func winePrefix(for region: GameRegion) -> URL {
		region.isChinaClient ? chinaWinePrefix : winePrefix
	}

	var logsDirectory: URL { logRoot }

	var logFile: URL {
		logsDirectory.appending(path: "wine.log")
	}

	var launcherLogFile: URL {
		logsDirectory.appending(path: "launcher.log")
	}

	func wineLogFile(for region: GameRegion) -> URL {
		region.isChinaClient ? logsDirectory.appending(path: "wine-cn.log") : logFile
	}

	var unityLogFile: URL {
		logsDirectory.appending(path: "unity.log")
	}

	var chromiumLogFile: URL {
		logsDirectory.appending(path: "chromium.log")
	}

	static let windowsUnityLogPath = "L:\\unity.log"

	var artworkCache: URL {
		cacheRoot.appending(path: "Artwork/Downloaded", directoryHint: .isDirectory)
	}

	var presetGalleryCache: URL {
		cacheRoot.appending(path: "PresetGallery", directoryHint: .isDirectory)
	}

	var dxmtCache: URL {
		dxmtCache(for: .global)
	}

	func dxmtCache(for region: GameRegion) -> URL {
		winePrefix(for: region).appending(path: "home/.cache/dxmt", directoryHint: .isDirectory)
	}

	func browserCacheDirectories(fileManager: FileManager = .default) -> [URL] {
		browserCacheDirectories(for: .global, fileManager: fileManager)
	}

	func browserCacheDirectories(
		for region: GameRegion,
		fileManager: FileManager = .default
	) -> [URL] {
		Self.gameCacheDirectories(winePrefix: winePrefix(for: region), fileManager: fileManager)
			.filter { $0 != dxmtCache(for: region) }
	}

	static func gameCacheDirectories(
		winePrefix: URL,
		fileManager: FileManager = .default
	) -> [URL] {
		let prefix = winePrefix.resolvingSymlinksInPath().standardizedFileURL
		let dxmt = winePrefix.appending(
			path: "home/.cache/dxmt", directoryHint: .isDirectory)
		var directories =
			isSafeCacheDirectory(
				dxmt, inside: prefix, fileManager: fileManager) ? [dxmt] : []
		let usersDirectory = winePrefix.appending(
			path: "drive_c/users", directoryHint: .isDirectory)
		guard
			let entries = try? fileManager.contentsOfDirectory(
				at: usersDirectory,
				includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
			)
		else { return directories }

		for entry in entries {
			guard
				let values = try? entry.resourceValues(forKeys: [
					.isDirectoryKey, .isSymbolicLinkKey,
				]),
				values.isDirectory == true,
				values.isSymbolicLink != true
			else { continue }
			let cache = entry.appending(
				path: "AppData/Local/cache", directoryHint: .isDirectory)
			if isSafeCacheDirectory(cache, inside: prefix, fileManager: fileManager) {
				directories.append(cache)
			}
		}
		return directories
	}

	static func isSafeCacheDirectory(
		_ url: URL,
		inside prefix: URL,
		fileManager: FileManager = .default
	) -> Bool {
		guard
			fileManager.fileExists(atPath: url.path),
			let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
			values.isDirectory == true,
			values.isSymbolicLink != true
		else { return false }

		let canonicalURL = url.resolvingSymlinksInPath().standardizedFileURL
		let prefixComponents = prefix.pathComponents
		return canonicalURL.pathComponents.starts(with: prefixComponents)
	}

	var customArtwork: URL {
		applicationSupportRoot.appending(path: "Artwork/Custom/artwork")
	}

	var customAppIcon: URL {
		applicationSupportRoot.appending(path: "Artwork/Custom/app-icon")
	}

	var customGameIcon: URL {
		applicationSupportRoot.appending(path: "Artwork/Custom/game-icon")
	}

	var operatorPresetAvatar: URL {
		applicationSupportRoot.appending(path: "Artwork/Custom/operator-avatar-source")
	}

	var playtimeStatistics: URL {
		applicationSupportRoot.appending(path: AppConstants.Playtime.statisticsFilename)
	}

}
