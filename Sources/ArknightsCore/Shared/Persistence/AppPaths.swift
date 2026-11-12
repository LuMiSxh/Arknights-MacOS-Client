// SPDX-License-Identifier: MPL-2.0

import ArknightsInfrastructure
import Foundation

enum AppPathsError: LocalizedError, Sendable {
	case cannotEnumerate(URL, reason: String)
	case cannotInspect(URL, reason: String)

	var errorDescription: String? {
		switch self {
		case .cannotEnumerate(let url, let reason):
			"Could not enumerate cache directory \(url.path): \(reason)"
		case .cannotInspect(let url, let reason):
			"Could not inspect cache directory \(url.path): \(reason)"
		}
	}
}

/// Every standard macOS location this app writes to, rooted under its bundle identifier;
/// the one place these paths are computed, so nothing hardcodes a repository-local path.
package struct AppPaths: Sendable {
	package static let bundleIdentifier = "com.lumisxh.arknights-client"

	package let applicationSupportRoot: URL
	let cacheRoot: URL
	let logRoot: URL
	/// Where saved diagnostics archives go: Downloads, or the support root when macOS has none.
	package let diagnosticsDirectory: URL
	/// Where screenshots go unless the user picks a folder: `Pictures/Arknights`. Visible to the
	/// user, unlike the support root.
	package let screenshotsDirectory: URL
	package let winePrefix: URL
	let chinaWinePrefix: URL
	let gryphlineWinePrefix: URL
	/// The selected runtime lane. Every publisher prefix and derived cache uses it.
	package let runtimeLane: RuntimeLane
	/// A problem reading `runtimeSelectionFile`, when the file exists but is unusable.
	package let runtimeLaneDiagnostic: String?
	/// The root of the downloaded, managed runtimes. Never inside the app bundle.
	package let runtimeRoot: URL
	/// Where runtime archives download before verification.
	package let runtimeDownloadsDirectory: URL
	/// Where a runtime archive extracts before it is installed.
	package let runtimeStagingRoot: URL
	/// The only persisted runtime choice, written atomically.
	package let runtimeSelectionFile: URL

	package init(
		fileManager: FileManager = .default,
		applicationSupportDirectory: URL? = nil,
		cachesDirectory: URL? = nil,
		libraryDirectory: URL? = nil,
		downloadsDirectory: URL? = nil,
		picturesDirectory: URL? = nil,
		runtimeSelection: RuntimeSelection? = nil,
		runtimeAccess: RuntimeAccess = RuntimeAccess()
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
		diagnosticsDirectory =
			downloadsDirectory
			?? fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
			?? applicationSupportRoot
		screenshotsDirectory =
			(picturesDirectory
			?? fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first
			?? fileManager.homeDirectoryForCurrentUser.appending(
				path: "Pictures", directoryHint: .isDirectory))
			.appending(
				path: AppConstants.Screenshots.defaultFolderName, directoryHint: .isDirectory)
		logRoot =
			libraryDirectory
			.appending(path: "Logs", directoryHint: .isDirectory)
			.appending(path: Self.bundleIdentifier, directoryHint: .isDirectory)
		runtimeRoot = applicationSupportRoot.appending(
			path: "Runtimes",
			directoryHint: .isDirectory
		)
		runtimeDownloadsDirectory = runtimeRoot.appending(
			path: ".downloads",
			directoryHint: .isDirectory
		)
		runtimeStagingRoot = runtimeRoot.appending(
			path: ".staging",
			directoryHint: .isDirectory
		)
		let selectionFile = applicationSupportRoot.appending(
			path: AppConstants.Runtime.runtimeSelectionFilename
		)
		runtimeSelectionFile = selectionFile

		let selection: RuntimeSelection
		var diagnostic: String?
		if let runtimeSelection {
			selection = runtimeSelection
		} else {
			do {
				selection = try RuntimeSelectionStore(fileURL: selectionFile).load(
					access: runtimeAccess)
			} catch {
				selection = RuntimeSelection(selected: runtimeAccess.defaultLane)
				diagnostic =
					"Could not read the runtime selection at \(selectionFile.path): "
					+ "\(error.localizedDescription); using the \(runtimeAccess.defaultLane.rawValue) lane"
			}
		}
		runtimeLaneDiagnostic = diagnostic
		runtimeLane = selection.selected
		let prefixName = selection.selected.prefixDirectoryName
		winePrefix = applicationSupportRoot.appending(
			path: "Yostar/\(prefixName)",
			directoryHint: .isDirectory
		)
		chinaWinePrefix = applicationSupportRoot.appending(
			path: "Hypergryph/\(prefixName)",
			directoryHint: .isDirectory
		)
		gryphlineWinePrefix = applicationSupportRoot.appending(
			path: "Gryphline/\(prefixName)",
			directoryHint: .isDirectory
		)
	}

	package func runtimeDirectory(for lane: RuntimeLane) -> URL {
		runtimeRoot.appending(path: lane.rawValue, directoryHint: .isDirectory)
	}

	package func runtimeVersionDirectory(for lane: RuntimeLane, version: String) -> URL {
		runtimeDirectory(for: lane)
			.appending(path: version, directoryHint: .isDirectory)
	}

	/// The installed version for `lane`, taken from the version directory that holds `RUNTIME.json`.
	package func installedRuntimeVersion(
		for lane: RuntimeLane,
		fileManager: FileManager = .default
	) -> String? {
		Self.installedRuntimeVersion(
			in: runtimeDirectory(for: lane), fileManager: fileManager)
	}

	/// The selected lane's installed `RUNTIME.json`, or `nil` when no runtime is installed.
	package func activeRuntimeConfigurationURL(
		for lane: RuntimeLane? = nil,
		fileManager: FileManager = .default
	) -> URL? {
		installedRuntimeConfigurationURL(
			for: lane ?? runtimeLane, fileManager: fileManager)
	}

	package func installedRuntimeConfigurationURL(
		for lane: RuntimeLane,
		fileManager: FileManager = .default
	) -> URL? {
		guard let version = installedRuntimeVersion(for: lane, fileManager: fileManager) else {
			return nil
		}
		return runtimeVersionDirectory(for: lane, version: version)
			.appending(path: "RUNTIME.json")
	}

	/// Both lanes' installed manifests, used by storage and diagnostics.
	package static func installedRuntimeConfigurationURLs(
		in runtimeRoot: URL,
		fileManager: FileManager = .default
	) -> [(lane: RuntimeLane, url: URL)] {
		RuntimeLane.allCases.compactMap { lane in
			let laneDirectory = runtimeRoot.appending(
				path: lane.rawValue, directoryHint: .isDirectory)
			guard let version = installedRuntimeVersion(in: laneDirectory, fileManager: fileManager)
			else { return nil }
			let url = laneDirectory.appending(path: version, directoryHint: .isDirectory)
				.appending(path: "RUNTIME.json")
			return (lane, url)
		}
	}

	private static func installedRuntimeVersion(
		in laneDirectory: URL,
		fileManager: FileManager
	) -> String? {
		let entries: [URL]
		do {
			entries = try fileManager.contentsOfDirectory(
				at: laneDirectory,
				includingPropertiesForKeys: [
					.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey,
				]
			)
		} catch {
			return nil
		}
		var newest: (version: String, modified: Date)?
		for entry in entries {
			let values: URLResourceValues
			do {
				values = try entry.resourceValues(forKeys: [
					.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey,
				])
			} catch {
				continue
			}
			guard values.isDirectory == true, values.isSymbolicLink != true else { continue }
			guard
				fileManager.fileExists(
					atPath: entry.appending(path: "RUNTIME.json").path)
			else { continue }
			let modified = values.contentModificationDate ?? .distantPast
			if let current = newest {
				if modified > current.modified {
					newest = (entry.lastPathComponent, modified)
				}
			} else {
				newest = (entry.lastPathComponent, modified)
			}
		}
		return newest?.version
	}

	package func gameInstall(for region: GameRegion) -> URL {
		let regionName =
			switch region {
			case .global: "Global"
			case .japan: "Japan"
			case .korea: "Korea"
			case .taiwan: "Taiwan"
			case .china: "China"
			case .chinaBilibili: "China-Bilibili"
			}
		return applicationSupportRoot.appending(
			path: "\(region.publisher.storageDirectoryName)/\(regionName)",
			directoryHint: .isDirectory
		)
	}

	package func winePrefix(for region: GameRegion) -> URL {
		winePrefix(for: region.publisher)
	}

	package func winePrefix(for publisher: GamePublisher) -> URL {
		winePrefix(for: publisher, lane: runtimeLane)
	}

	package func winePrefix(for region: GameRegion, lane: RuntimeLane) -> URL {
		winePrefix(for: region.publisher, lane: lane)
	}

	/// The publisher prefix of either lane. Storage and cleanup see both lanes.
	package func winePrefix(for publisher: GamePublisher, lane: RuntimeLane) -> URL {
		applicationSupportRoot.appending(
			path: "\(publisher.storageDirectoryName)/\(lane.prefixDirectoryName)",
			directoryHint: .isDirectory
		)
	}

	package var logsDirectory: URL { logRoot }

	/// Where the publisher SDK writes its logs inside the publisher's Wine prefix.
	package func sdkLogDirectory(for publisher: GamePublisher) -> URL {
		sdkLogDirectory(for: publisher, lane: runtimeLane)
	}

	package func sdkLogDirectory(for publisher: GamePublisher, lane: RuntimeLane) -> URL {
		winePrefix(for: publisher, lane: lane).appending(
			path: "drive_c/users/crossover/AppData/LocalLow/HyperGryph/Arknights/sdklogs",
			directoryHint: .isDirectory
		)
	}

	/// Where the launcher keeps copies of the publisher SDK logs.
	package func collectedSDKLogDirectory(for publisher: GamePublisher) -> URL {
		logsDirectory.appending(path: "sdklogs/\(publisher.rawValue)", directoryHint: .isDirectory)
	}

	var yostarLogFile: URL {
		publisherLogFile(for: .yostar)
	}

	package var launcherLogFile: URL {
		logsDirectory.appending(path: "launcher.log")
	}

	package func publisherLogFile(for publisher: GamePublisher) -> URL {
		logsDirectory.appending(path: publisher.runtimeLogFileName)
	}

	package func runtimeLogFile(for region: GameRegion) -> URL {
		publisherLogFile(for: region.publisher)
	}

	package var unityLogFile: URL {
		logsDirectory.appending(path: "unity.log")
	}

	package var chromiumLogFile: URL {
		logsDirectory.appending(path: "chromium.log")
	}

	package static let windowsUnityLogPath = "L:\\unity.log"

	package var artworkCache: URL {
		cacheRoot.appending(path: "Artwork/Downloaded", directoryHint: .isDirectory)
	}

	package var presetGalleryCache: URL {
		cacheRoot.appending(path: "PresetGallery", directoryHint: .isDirectory)
	}

	var dxmtCache: URL {
		dxmtCache(for: .global)
	}

	package func dxmtCache(for region: GameRegion) -> URL {
		dxmtCache(for: region, lane: runtimeLane)
	}

	package func dxmtCache(for region: GameRegion, lane: RuntimeLane) -> URL {
		winePrefix(for: region, lane: lane)
			.appending(path: "home/.cache/dxmt", directoryHint: .isDirectory)
	}

	package func browserCacheDirectories(fileManager: FileManager = .default) throws -> [URL] {
		try browserCacheDirectories(for: .global, fileManager: fileManager)
	}

	package func browserCacheDirectories(
		for region: GameRegion,
		fileManager: FileManager = .default
	) throws -> [URL] {
		try browserCacheDirectories(for: region, lane: runtimeLane, fileManager: fileManager)
	}

	package func browserCacheDirectories(
		for region: GameRegion,
		lane: RuntimeLane,
		fileManager: FileManager = .default
	) throws -> [URL] {
		let prefix = winePrefix(for: region, lane: lane)
		return try Self.gameCacheDirectories(winePrefix: prefix, fileManager: fileManager)
			.filter { $0 != dxmtCache(for: region, lane: lane) }
	}

	package static func gameCacheDirectories(
		winePrefix: URL,
		fileManager: FileManager = .default
	) throws -> [URL] {
		let prefix = winePrefix.resolvingSymlinksInPath().standardizedFileURL
		let dxmt = winePrefix.appending(
			path: "home/.cache/dxmt", directoryHint: .isDirectory)
		var directories: [URL] = []
		if try isSafeCacheDirectory(dxmt, inside: prefix, fileManager: fileManager) {
			directories.append(dxmt)
		}
		let usersDirectory = winePrefix.appending(
			path: "drive_c/users", directoryHint: .isDirectory)
		let entries: [URL]
		do {
			entries = try fileManager.contentsOfDirectory(
				at: usersDirectory,
				includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
			)
		} catch  where isMissingPathError(error) {
			return directories
		} catch {
			throw AppPathsError.cannotEnumerate(
				usersDirectory,
				reason: error.localizedDescription
			)
		}

		for entry in entries {
			let values: URLResourceValues
			do {
				values = try entry.resourceValues(forKeys: [
					.isDirectoryKey, .isSymbolicLinkKey,
				])
			} catch  where isMissingPathError(error) {
				continue
			} catch {
				throw AppPathsError.cannotInspect(
					entry,
					reason: error.localizedDescription
				)
			}
			guard values.isDirectory == true, values.isSymbolicLink != true else { continue }
			let cache = entry.appending(
				path: "AppData/Local/cache", directoryHint: .isDirectory)
			if try isSafeCacheDirectory(cache, inside: prefix, fileManager: fileManager) {
				directories.append(cache)
			}
		}
		return directories
	}

	package static func isSafeCacheDirectory(
		_ url: URL,
		inside prefix: URL,
		fileManager: FileManager = .default
	) throws -> Bool {
		_ = fileManager
		let values: URLResourceValues
		do {
			values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
		} catch  where isMissingPathError(error) {
			return false
		} catch {
			throw AppPathsError.cannotInspect(url, reason: error.localizedDescription)
		}
		guard values.isDirectory == true, values.isSymbolicLink != true else { return false }

		let canonicalURL = url.resolvingSymlinksInPath().standardizedFileURL
		let prefixComponents = prefix.pathComponents
		return canonicalURL.pathComponents.starts(with: prefixComponents)
	}

	package static func isMissingPathError(_ error: any Error) -> Bool {
		if let error = error as? CocoaError {
			return error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile
		}
		if let error = error as? POSIXError {
			return error.code == .ENOENT || error.code == .ENOTDIR
		}

		let error = error as NSError
		if error.domain == NSPOSIXErrorDomain {
			return error.code == Int(ENOENT) || error.code == Int(ENOTDIR)
		}
		return error.domain == NSCocoaErrorDomain
			&& (error.code == CocoaError.fileNoSuchFile.rawValue
				|| error.code == CocoaError.fileReadNoSuchFile.rawValue)
	}

	package var customArtwork: URL {
		applicationSupportRoot.appending(path: "Artwork/Custom/artwork")
	}

	package var customAppIcon: URL {
		applicationSupportRoot.appending(path: "Artwork/Custom/app-icon")
	}

	package var customGameIcon: URL {
		applicationSupportRoot.appending(path: "Artwork/Custom/game-icon")
	}

	package var operatorPresetAvatar: URL {
		applicationSupportRoot.appending(path: "Artwork/Custom/operator-avatar-source")
	}

	package var storageOverviewCache: URL {
		applicationSupportRoot.appending(path: AppConstants.Storage.overviewCacheFilename)
	}

	package var playtimeStatistics: URL {
		applicationSupportRoot.appending(path: AppConstants.Playtime.statisticsFilename)
	}

}
