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

	var logsDirectory: URL { logRoot }

	var logFile: URL {
		logsDirectory.appending(path: "wine.log")
	}

	var launcherLogFile: URL {
		logsDirectory.appending(path: "launcher.log")
	}

	var unityLogFile: URL {
		logsDirectory.appending(path: "unity.log")
	}

	var chromiumLogFile: URL {
		logsDirectory.appending(path: "chromium.log")
	}

	static let windowsUnityLogPath = "L:\\unity.log"

	/// Unity writes its own log independently of the launcher's `wine.log`, into the
	/// Windows user profile Wine creates for `NSUserName()` (see `WinePrefixConfigurator`).
	func unityLogFile(for region: GameRegion, userName: String = NSUserName()) -> URL {
		winePrefix.appending(
			path: "drive_c/users/\(userName)/AppData/LocalLow/Yostar/\(region.gameTag)/unity.log"
		)
	}

	/// The Vuplex/Chromium helper is region-agnostic since only one region's prefix is
	/// active at a time, so its log lives directly under the shared Yostar folder.
	func chromiumLogFile(userName: String = NSUserName()) -> URL {
		winePrefix.appending(
			path: "drive_c/users/\(userName)/AppData/LocalLow/Yostar/chromium.log"
		)
	}

	static func windowsUnityLogPath(for region: GameRegion, userName: String = NSUserName())
		-> String
	{
		"C:\\users\\\(userName)\\AppData\\LocalLow\\Yostar\\\(region.gameTag)\\unity.log"
	}

	var artworkCache: URL {
		cacheRoot.appending(path: "Artwork/Downloaded", directoryHint: .isDirectory)
	}

	var presetGalleryCache: URL {
		cacheRoot.appending(path: "PresetGallery", directoryHint: .isDirectory)
	}

	var dxmtCache: URL {
		winePrefix.appending(path: "home/.cache/dxmt", directoryHint: .isDirectory)
	}

	func browserCacheDirectories(fileManager: FileManager = .default) -> [URL] {
		Self.gameCacheDirectories(winePrefix: winePrefix, fileManager: fileManager)
			.filter { $0 != dxmtCache }
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

}
