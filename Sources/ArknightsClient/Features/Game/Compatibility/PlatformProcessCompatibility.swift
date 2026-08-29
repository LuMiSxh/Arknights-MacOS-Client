// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Swaps the Notices helper (`PlatformProcess.exe`) for a shim that loads
/// `PlatformProcessWindowBridge.dylib`, which gives that window macOS-native transparency
/// and layering instead of the opaque black surface Wine renders by default.
struct PlatformProcessCompatibility: GameCompatibilityComponent {
	let identifier = "platform-process-window"
	static let helperRelativePath = "PlatformProcess.exe"
	static let originalHelperName = "PlatformProcess.original.helper.exe"
	static let bridgeName = "PlatformProcessWindowBridge.dylib"
	static let launcherShimMarker = Data(
		"Arknights Client PlatformProcess compatibility".utf8)
	static let launcherBridgeMarker = Data(
		"Arknights Client PlatformProcess window bridge".utf8)
	private static let officialHelperMarker = Data("PlatformProcess.exe".utf8)
	private static let maximumAssetSize = 4 * 1_048_576
	private static let temporaryPrefix = ".arknights-client-platform-process-"

	private let shimURL: URL?
	private let bridgeURL: URL?

	init(bundle: Bundle = .main) {
		let directory = bundle.resourceURL?
			.appending(path: "Compatibility/PlatformProcess", directoryHint: .isDirectory)
		shimURL = directory?.appending(path: "PlatformProcess.exe")
		bridgeURL = directory?.appending(path: Self.bridgeName)
	}

	init(shimURL: URL?, bridgeURL: URL?) {
		self.shimURL = shimURL
		self.bridgeURL = bridgeURL
	}

	@discardableResult
	func installIfSupported(
		in gameDirectory: URL,
		fileManager: FileManager = .default
	) throws -> Bool {
		let helper = gameDirectory.appending(path: Self.helperRelativePath)
		let original = gameDirectory.appending(path: Self.originalHelperName)
		let installedBridge = gameDirectory.appending(path: Self.bridgeName)
		try recoverMissingHelper(helper: helper, original: original, fileManager: fileManager)
		try removeTemporaryFiles(in: gameDirectory, fileManager: fileManager)
		guard let shimURL, let bridgeURL,
			fileManager.fileExists(atPath: shimURL.path),
			fileManager.fileExists(atPath: bridgeURL.path),
			fileManager.fileExists(atPath: helper.path)
		else { return false }

		let helperIsShim = try GameShimIO.containsMarker(
			at: helper,
			marker: Self.launcherShimMarker,
			maximumSize: Self.maximumAssetSize
		)
		let officialHelper = helperIsShim ? original : helper
		if helperIsShim, !fileManager.fileExists(atPath: original.path) {
			throw LauncherError.gameCompatibility(
				"The official PlatformProcess helper is missing. Repair the game before launching."
			)
		}
		guard try GameShimIO.containsMarker(at: officialHelper, marker: Self.officialHelperMarker)
		else {
			return false
		}
		if fileManager.fileExists(atPath: installedBridge.path),
			try !GameShimIO.containsMarker(
				at: installedBridge,
				marker: Self.launcherBridgeMarker,
				maximumSize: Self.maximumAssetSize
			)
		{
			throw LauncherError.gameCompatibility(
				"The game directory contains an unknown PlatformProcess window bridge."
			)
		}
		let shimMatches = fileManager.contentsEqual(atPath: helper.path, andPath: shimURL.path)
		let bridgeMatches = fileManager.contentsEqual(
			atPath: installedBridge.path,
			andPath: bridgeURL.path
		)
		guard !shimMatches || !bridgeMatches else { return false }

		let stagedBridge = temporaryURL(in: gameDirectory, suffix: "bridge")
		defer { try? fileManager.removeItem(at: stagedBridge) }
		try fileManager.copyItem(at: bridgeURL, to: stagedBridge)
		try GameShimIO.swapHelper(
			at: helper,
			with: shimURL,
			backupURL: original,
			isCurrentlyInstalledShim: helperIsShim,
			temporaryPrefix: "\(Self.temporaryPrefix)shim-",
			previousPrefix: "\(Self.temporaryPrefix)previous-",
			fileManager: fileManager
		) {
			try? fileManager.removeItem(at: installedBridge)
			try fileManager.moveItem(at: stagedBridge, to: installedBridge)
		}
		return true
	}

	@discardableResult
	func restoreIfInstalled(
		in gameDirectory: URL,
		fileManager: FileManager = .default
	) throws -> Bool {
		let helper = gameDirectory.appending(path: Self.helperRelativePath)
		let original = gameDirectory.appending(path: Self.originalHelperName)
		let installedBridge = gameDirectory.appending(path: Self.bridgeName)
		try recoverMissingHelper(helper: helper, original: original, fileManager: fileManager)
		try removeTemporaryFiles(in: gameDirectory, fileManager: fileManager)
		var changed = false
		if fileManager.fileExists(atPath: original.path) {
			if fileManager.fileExists(atPath: helper.path),
				try GameShimIO.containsMarker(
					at: helper,
					marker: Self.launcherShimMarker,
					maximumSize: Self.maximumAssetSize
				)
			{
				try fileManager.removeItem(at: helper)
				try fileManager.moveItem(at: original, to: helper)
				changed = true
			} else {
				try fileManager.removeItem(at: original)
			}
		}
		if fileManager.fileExists(atPath: installedBridge.path),
			try GameShimIO.containsMarker(
				at: installedBridge,
				marker: Self.launcherBridgeMarker,
				maximumSize: Self.maximumAssetSize
			)
		{
			try fileManager.removeItem(at: installedBridge)
			changed = true
		}
		return changed
	}

	private func recoverMissingHelper(
		helper: URL,
		original: URL,
		fileManager: FileManager
	) throws {
		if !fileManager.fileExists(atPath: helper.path),
			fileManager.fileExists(atPath: original.path)
		{
			try fileManager.moveItem(at: original, to: helper)
		}
	}

	private func removeTemporaryFiles(in directory: URL, fileManager: FileManager) throws {
		try GameShimIO.removeStaleTemporaryFiles(
			in: directory,
			matchingPrefixes: [Self.temporaryPrefix],
			fileManager: fileManager
		)
	}

	private func temporaryURL(in directory: URL, suffix: String) -> URL {
		directory.appending(path: "\(Self.temporaryPrefix)\(suffix)-\(UUID().uuidString)")
	}
}
