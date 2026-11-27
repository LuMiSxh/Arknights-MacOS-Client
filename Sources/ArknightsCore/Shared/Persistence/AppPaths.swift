// SPDX-License-Identifier: MPL-2.0

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
	/// The selected runtime lane. Every publisher prefix and derived cache uses it.
	package let runtimeLane: RuntimeLane
	/// The user's lane override when the OS allows it. Nil means the launcher chose `runtimeLane`.
	package let runtimeLaneOverride: RuntimeLane?
	/// A problem reading `runtimeSelectionFile`, when the file exists but is unusable.
	package let runtimeLaneDiagnostic: String?
	/// The root of the downloaded, managed runtimes. Never inside the app bundle.
	package let runtimeRoot: URL
	/// Where runtime archives download before verification.
	package let runtimeDownloadsDirectory: URL
	/// Where a runtime archive extracts before it is installed.
	package let runtimeStagingRoot: URL
	/// The persisted runtime document: the selected lane and installed versions, written atomically.
	package let runtimeSelectionFile: URL
	/// Records the Application Support layout version. A missing file means the 0.6/0.7 layout.
	package let layoutFile: URL

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
			?? Self.userDomainDirectory(.applicationSupportDirectory, fileManager)
		let cachesDirectory =
			cachesDirectory
			?? Self.userDomainDirectory(.cachesDirectory, fileManager)
		let libraryDirectory =
			libraryDirectory
			?? Self.userDomainDirectory(.libraryDirectory, fileManager)

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
		runtimeDownloadsDirectory = applicationSupportRoot.appending(
			path: "Downloads",
			directoryHint: .isDirectory
		)
		runtimeStagingRoot = runtimeDownloadsDirectory.appending(
			path: ".staging",
			directoryHint: .isDirectory
		)
		let selectionFile = applicationSupportRoot.appending(
			path: AppConstants.Runtime.runtimeSelectionFilename
		)
		runtimeSelectionFile = selectionFile
		layoutFile = applicationSupportRoot.appending(
			path: AppConstants.Storage.layoutFilename
		)

		let selection: RuntimeSelection
		var diagnostic: String?
		if let runtimeSelection {
			selection = runtimeSelection
		} else {
			do {
				// A lock-free read is safe here: `JSONFileStore.write` replaces the file
				// atomically, so a concurrent writer never exposes a partial document.
				selection = try RuntimeSelectionStore(fileURL: selectionFile).load()
			} catch {
				selection = RuntimeSelection()
				diagnostic =
					"Could not read the runtime selection at \(selectionFile.path): "
					+ "\(error.localizedDescription); using the \(runtimeAccess.defaultLane.rawValue) lane"
			}
		}
		runtimeLaneDiagnostic = diagnostic
		runtimeLane = selection.effectiveLane(access: runtimeAccess)
		runtimeLaneOverride = selection.validOverride(access: runtimeAccess)
	}

	private static func environmentDirectoryName(
		for publisher: GamePublisher,
		lane: RuntimeLane
	) -> String {
		"\(publisher.rawValue)-\(lane.rawValue)"
	}

	private static func userDomainDirectory(
		_ directory: FileManager.SearchPathDirectory,
		_ fileManager: FileManager
	) -> URL {
		guard let url = fileManager.urls(for: directory, in: .userDomainMask).first else {
			fatalError("macOS reports no \(directory) in the user domain")
		}
		return url
	}

	package func runtimeDownloadsDirectory(for lane: RuntimeLane) -> URL {
		runtimeDownloadsDirectory.appending(path: lane.rawValue, directoryHint: .isDirectory)
	}

	package func runtimeVersionDirectory(for lane: RuntimeLane, version: String) -> URL {
		Self.runtimeVersionDirectory(in: runtimeRoot, lane: lane, version: version)
	}

	private static func runtimeVersionDirectory(
		in runtimeRoot: URL,
		lane: RuntimeLane,
		version: String
	) -> URL {
		runtimeRoot.appending(
			path: "\(lane.rawValue)-\(version)", directoryHint: .isDirectory)
	}

	/// The per-lane lease directory. It exists only to hold the install lock.
	package func runtimeLeaseDirectory(for lane: RuntimeLane) -> URL {
		runtimeRoot.appending(path: ".leases", directoryHint: .isDirectory)
			.appending(path: lane.rawValue, directoryHint: .isDirectory)
	}

	/// The installed version for `lane`, taken from the runtime document.
	package func installedRuntimeVersion(for lane: RuntimeLane) -> String? {
		Self.installedRuntimeVersion(for: lane, selectionFile: runtimeSelectionFile)
	}

	private static func installedRuntimeVersion(
		for lane: RuntimeLane,
		selectionFile: URL
	) -> String? {
		do {
			return try RuntimeSelectionStore(fileURL: selectionFile).load()
				.installedVersion(for: lane)
		} catch {
			return nil
		}
	}

	/// The lane's installed `RUNTIME.json`, or `nil` when no runtime is installed.
	package func installedRuntimeConfigurationURL(for lane: RuntimeLane) -> URL? {
		guard let version = installedRuntimeVersion(for: lane) else { return nil }
		return runtimeVersionDirectory(for: lane, version: version)
			.appending(path: "RUNTIME.json")
	}

	/// Both lanes' installed manifests, used by diagnostics.
	package static func installedRuntimeConfigurationURLs(
		applicationSupportRoot: URL
	) -> [(lane: RuntimeLane, url: URL)] {
		let runtimeRoot = applicationSupportRoot.appending(
			path: "Runtimes", directoryHint: .isDirectory)
		let selectionFile = applicationSupportRoot.appending(
			path: AppConstants.Runtime.runtimeSelectionFilename)
		return RuntimeLane.allCases.compactMap { lane in
			guard let version = installedRuntimeVersion(for: lane, selectionFile: selectionFile)
			else { return nil }
			let url = runtimeVersionDirectory(in: runtimeRoot, lane: lane, version: version)
				.appending(path: "RUNTIME.json")
			return (lane, url)
		}
	}

	package func gameInstall(for region: GameRegion) -> URL {
		applicationSupportRoot.appending(
			path: "Games/\(region.serverIdentifier)",
			directoryHint: .isDirectory
		)
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
			path: "Environments/\(Self.environmentDirectoryName(for: publisher, lane: lane))",
			directoryHint: .isDirectory
		)
	}

	package var logsDirectory: URL { logRoot }

	/// Where the publisher SDK writes its logs inside the publisher's Wine prefix.
	///
	/// The SDK writes under the prefix user's profile. That user is the macOS account name or
	/// `crossover`, so this lists the folder of every profile.
	package func sdkLogDirectories(
		for publisher: GamePublisher,
		lane: RuntimeLane,
		fileManager: FileManager = .default
	) throws -> [URL] {
		let users = winePrefix(for: publisher, lane: lane).appending(
			path: "drive_c/users", directoryHint: .isDirectory)
		let profiles: [URL]
		do {
			profiles = try fileManager.contentsOfDirectory(
				at: users, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
		} catch  where Self.isMissingPathError(error) {
			return []
		}
		// Every folder from the profile down must be a real directory, so a link never leads out of the prefix.
		return try profiles.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap {
			profile in
			let logs = profile.appending(
				path: "AppData/LocalLow/HyperGryph/Arknights/sdklogs", directoryHint: .isDirectory)
			return try DiagnosticsFileSelection.isPlainFolder(logs, below: users) ? logs : nil
		}
	}

	/// Where macOS writes crash reports for the current user.
	package static var systemCrashReportsDirectory: URL {
		FileManager.default.homeDirectoryForCurrentUser.appending(
			path: "Library/Logs/DiagnosticReports", directoryHint: .isDirectory)
	}

	/// Where a log moves when the next session replaces it: `unity.log` becomes `unity.previous.log`.
	package static func previousLogFile(of log: URL) -> URL {
		log.deletingPathExtension().appendingPathExtension("previous.log")
	}

	/// Where the log before the previous one moves: `unity.previous.log` becomes
	/// `unity.previous-2.log`.
	package static func previousSecondLogFile(of log: URL) -> URL {
		log.deletingPathExtension().appendingPathExtension("previous-2.log")
	}

	/// Where the launcher keeps copies of the publisher SDK logs.
	package func collectedSDKLogDirectory(for publisher: GamePublisher) -> URL {
		logsDirectory.appending(path: "sdklogs/\(publisher.rawValue)", directoryHint: .isDirectory)
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
		cacheRoot.appending(path: "Artwork", directoryHint: .isDirectory)
	}

	package var presetGalleryCache: URL {
		cacheRoot.appending(path: "Presets", directoryHint: .isDirectory)
	}

	/// Derived theme values (artwork accents, home luminance); rebuilt when missing.
	package var themeCache: URL {
		cacheRoot.appending(path: "Theme/theme.json")
	}

	package func dxmtCache(for region: GameRegion, lane: RuntimeLane) -> URL {
		winePrefix(for: region, lane: lane)
			.appending(path: "home/.cache/dxmt", directoryHint: .isDirectory)
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
		if try isSafeCacheDirectory(dxmt, inside: prefix) {
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
			if try isSafeCacheDirectory(cache, inside: prefix) {
				directories.append(cache)
			}
		}
		return directories
	}

	package static func isSafeCacheDirectory(
		_ url: URL,
		inside prefix: URL
	) throws -> Bool {
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

	/// Holds the user's chosen artwork, app icon, and logo source.
	var artworkDirectory: URL {
		applicationSupportRoot.appending(path: "Artwork", directoryHint: .isDirectory)
	}

	package var customArtwork: URL {
		artworkDirectory.appending(path: "artwork")
	}

	/// The persisted background video is named by its container, because AVFoundation picks the
	/// parser from the file extension.
	package enum CustomVideoContainer: String, CaseIterable {
		case mp4
		case mov
	}

	package func customVideo(_ container: CustomVideoContainer) -> URL {
		artworkDirectory.appending(path: "artwork-video.\(container.rawValue)")
	}

	package var customVideoFiles: [URL] {
		CustomVideoContainer.allCases.map { customVideo($0) }
	}

	package var customVideoPoster: URL {
		artworkDirectory.appending(path: "artwork-video-poster")
	}

	package var customAppIcon: URL {
		artworkDirectory.appending(path: "app-icon")
	}

	package var customGameIcon: URL {
		artworkDirectory.appending(path: "game-icon")
	}

	package var operatorPresetAvatar: URL {
		artworkDirectory.appending(path: "operator-avatar-source")
	}

	/// The pre-0.8 custom artwork folder, flat in the new layout.
	var legacyCustomArtworkDirectory: URL {
		artworkDirectory.appending(path: "Custom", directoryHint: .isDirectory)
	}

	/// A cache folder that pre-0.8 builds wrote; the migration deletes it.
	var legacyArtworkDownloadCache: URL {
		cacheRoot.appending(path: "Artwork/Downloaded", directoryHint: .isDirectory)
	}

	/// A cache folder that pre-0.8 builds wrote; the migration deletes it.
	var legacyPresetGalleryCache: URL {
		cacheRoot.appending(path: "PresetGallery", directoryHint: .isDirectory)
	}

	package var storageOverviewCache: URL {
		cacheRoot.appending(path: "Storage/overview.json")
	}

	package var playtimeStatistics: URL {
		applicationSupportRoot.appending(path: AppConstants.Playtime.statisticsFilename)
	}

}
