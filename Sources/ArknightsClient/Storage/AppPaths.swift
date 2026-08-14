// SPDX-License-Identifier: MPL-2.0

import Foundation

struct AppPaths: Sendable {
	static let bundleIdentifier = "com.lumisxh.arknights-client"

	let applicationSupportRoot: URL
	let cacheRoot: URL
	let logRoot: URL
	let globalGameInstall: URL
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
		globalGameInstall = applicationSupportRoot.appending(
			path: "Games/Arknights-Global",
			directoryHint: .isDirectory
		)
		winePrefix = applicationSupportRoot.appending(
			path: "Wine/Prefixes/Arknights-Global",
			directoryHint: .isDirectory
		)
	}

	var logsDirectory: URL { logRoot }

	var logFile: URL {
		logsDirectory.appending(path: "wine.log")
	}

	var artworkCache: URL {
		cacheRoot.appending(path: "Artwork/Downloaded", directoryHint: .isDirectory)
	}

	var customArtwork: URL {
		applicationSupportRoot.appending(path: "Artwork/Custom/artwork")
	}

	var launcherUpdateCache: URL {
		cacheRoot.appending(path: "Updater", directoryHint: .isDirectory)
	}
}
