// SPDX-License-Identifier: MPL-2.0

import Foundation

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

		let helperIsShim = try isLauncherAsset(
			at: helper,
			marker: Self.launcherShimMarker
		)
		let officialHelper = helperIsShim ? original : helper
		if helperIsShim, !fileManager.fileExists(atPath: original.path) {
			throw LauncherError.runtimeConfiguration(
				"The official PlatformProcess helper is missing. Repair the game before launching."
			)
		}
		guard try containsMarker(Self.officialHelperMarker, at: officialHelper) else {
			return false
		}
		if fileManager.fileExists(atPath: installedBridge.path),
			try !isLauncherAsset(at: installedBridge, marker: Self.launcherBridgeMarker)
		{
			throw LauncherError.runtimeConfiguration(
				"The game directory contains an unknown PlatformProcess window bridge."
			)
		}
		let shimMatches = fileManager.contentsEqual(atPath: helper.path, andPath: shimURL.path)
		let bridgeMatches = fileManager.contentsEqual(
			atPath: installedBridge.path,
			andPath: bridgeURL.path
		)
		guard !shimMatches || !bridgeMatches else { return false }

		let stagedShim = temporaryURL(in: gameDirectory, suffix: "shim")
		let stagedBridge = temporaryURL(in: gameDirectory, suffix: "bridge")
		let previousShim = temporaryURL(in: gameDirectory, suffix: "previous")
		defer {
			try? fileManager.removeItem(at: stagedShim)
			try? fileManager.removeItem(at: stagedBridge)
			try? fileManager.removeItem(at: previousShim)
		}
		try fileManager.copyItem(at: shimURL, to: stagedShim)
		try fileManager.copyItem(at: bridgeURL, to: stagedBridge)
		if helperIsShim {
			try fileManager.moveItem(at: helper, to: previousShim)
		} else {
			try? fileManager.removeItem(at: original)
			try fileManager.moveItem(at: helper, to: original)
		}
		do {
			try fileManager.moveItem(at: stagedShim, to: helper)
			try? fileManager.removeItem(at: installedBridge)
			try fileManager.moveItem(at: stagedBridge, to: installedBridge)
		} catch {
			try? fileManager.removeItem(at: helper)
			if fileManager.fileExists(atPath: previousShim.path) {
				try? fileManager.moveItem(at: previousShim, to: helper)
			} else {
				try? fileManager.moveItem(at: original, to: helper)
			}
			throw error
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
				try isLauncherAsset(at: helper, marker: Self.launcherShimMarker)
			{
				try fileManager.removeItem(at: helper)
				try fileManager.moveItem(at: original, to: helper)
				changed = true
			} else {
				try fileManager.removeItem(at: original)
			}
		}
		if fileManager.fileExists(atPath: installedBridge.path),
			try isLauncherAsset(at: installedBridge, marker: Self.launcherBridgeMarker)
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
		guard fileManager.fileExists(atPath: directory.path) else { return }
		for url in try fileManager.contentsOfDirectory(
			at: directory,
			includingPropertiesForKeys: nil
		) where url.lastPathComponent.hasPrefix(Self.temporaryPrefix) {
			try fileManager.removeItem(at: url)
		}
	}

	private func temporaryURL(in directory: URL, suffix: String) -> URL {
		directory.appending(path: "\(Self.temporaryPrefix)\(suffix)-\(UUID().uuidString)")
	}

	private func containsMarker(_ marker: Data, at url: URL) throws -> Bool {
		let data = try Data(contentsOf: url, options: .mappedIfSafe)
		return data.range(of: marker) != nil
	}

	private func isLauncherAsset(at url: URL, marker: Data) throws -> Bool {
		let data = try Data(contentsOf: url, options: .mappedIfSafe)
		guard data.count <= Self.maximumAssetSize else { return false }
		return data.range(of: marker) != nil
	}
}
