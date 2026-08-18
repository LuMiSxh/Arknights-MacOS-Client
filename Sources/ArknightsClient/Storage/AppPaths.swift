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

	init(
		fileManager: FileManager = .default,
		applicationSupportDirectory: URL? = nil,
		cachesDirectory: URL? = nil,
		libraryDirectory: URL? = nil
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

	var customArtwork: URL {
		applicationSupportRoot.appending(path: "Artwork/Custom/artwork")
	}

	var customAppIcon: URL {
		applicationSupportRoot.appending(path: "Artwork/Custom/app-icon")
	}

}
