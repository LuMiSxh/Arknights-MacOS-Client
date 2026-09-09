// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Installs the Bilibili login-window controller without replacing Bilibili's platform helper.
struct BilibiliPlatformCompatibility: GameCompatibilityComponent {
	let identifier = "bilibili-platform"
	static let helperDirectory = "BLPlatform64"
	static let helperName = "PCGamePlatform.exe"
	static let controllerName = "BilibiliWindowController.exe"
	static let originalDirectoryName = ".arknights-client-bilibili"
	static let browserDirectoryName = "BLWebBrowser"
	static let injectionName = "PCGamePlatformInjection.dylib"
	static let bridgeName = "PCGamePlatformWindowBridge.dylib"
	static let launcherControllerMarker = Data(
		"Arknights Client Bilibili window controller".utf8)
	private static let launcherShimMarkers = [
		Data("Arknights Client Bilibili platform compatibility".utf8),
		Data("Arknights Client Bilibili single-process compatibility".utf8),
	]
	static let launcherBridgeMarker = Data(
		"Arknights Client Bilibili platform window bridge".utf8)
	static let launcherInjectionMarker = Data(
		"Arknights Client Bilibili platform injection selector".utf8)
	private static let officialHelperMarker = Data("PCGamePlatform.exe".utf8)
	private static let temporaryPrefix = ".arknights-client-bilibili-platform-"

	private let controllerURL: URL?

	init(bundle: Bundle = .main) {
		let directory = bundle.resourceURL?.appending(
			path: "Compatibility/BilibiliPlatform", directoryHint: .isDirectory)
		controllerURL = directory?.appending(path: Self.controllerName)
	}

	init(controllerURL: URL?) {
		self.controllerURL = controllerURL
	}

	@discardableResult
	func installIfSupported(
		in gameDirectory: URL,
		fileManager: FileManager = .default
	) throws -> Bool {
		let paths = paths(in: gameDirectory)
		var changed = try migrateLegacyWrapper(paths: paths, fileManager: fileManager)
		try removeTemporaryFiles(in: paths.directory, fileManager: fileManager)
		changed = try removeLegacyArtifacts(paths: paths, fileManager: fileManager) || changed
		changed = try removeOwnedLegacyStorage(paths: paths, fileManager: fileManager) || changed
		guard let controllerURL,
			fileManager.fileExists(atPath: controllerURL.path),
			fileManager.fileExists(atPath: paths.helper.path)
		else { return changed }

		guard try containsMarker(Self.officialHelperMarker, at: paths.helper) else {
			return changed
		}
		try validateOwnedController(paths: paths, fileManager: fileManager)
		let controllerMatches = fileManager.contentsEqual(
			atPath: paths.controller.path, andPath: controllerURL.path)
		guard !controllerMatches else { return changed }

		let stagedController = temporaryURL(in: paths.directory, suffix: "controller")
		let previousController = temporaryURL(in: paths.directory, suffix: "previous-controller")
		defer {
			try? fileManager.removeItem(at: stagedController)
			try? fileManager.removeItem(at: previousController)
		}
		try fileManager.copyItem(at: controllerURL, to: stagedController)
		if fileManager.fileExists(atPath: paths.controller.path) {
			try fileManager.moveItem(at: paths.controller, to: previousController)
		}
		do {
			try fileManager.moveItem(at: stagedController, to: paths.controller)
			try? fileManager.removeItem(at: previousController)
		} catch {
			try? fileManager.removeItem(at: paths.controller)
			if fileManager.fileExists(atPath: previousController.path) {
				try? fileManager.moveItem(at: previousController, to: paths.controller)
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
		let paths = paths(in: gameDirectory)
		var changed = try migrateLegacyWrapper(paths: paths, fileManager: fileManager)
		try removeTemporaryFiles(in: paths.directory, fileManager: fileManager)
		changed = try removeLegacyArtifacts(paths: paths, fileManager: fileManager) || changed
		if fileManager.fileExists(atPath: paths.controller.path),
			try containsMarker(Self.launcherControllerMarker, at: paths.controller)
		{
			try fileManager.removeItem(at: paths.controller)
			changed = true
		}
		changed = try removeOwnedLegacyStorage(paths: paths, fileManager: fileManager) || changed
		return changed
	}

	private func migrateLegacyWrapper(
		paths: Paths,
		fileManager: FileManager
	) throws -> Bool {
		let helperExists = fileManager.fileExists(atPath: paths.helper.path)
		let originalExists = fileManager.fileExists(atPath: paths.original.path)
		let helperIsLegacyShim: Bool
		if helperExists {
			helperIsLegacyShim = try isLegacyShim(at: paths.helper)
		} else {
			helperIsLegacyShim = false
		}

		if helperIsLegacyShim {
			guard originalExists else {
				throw LauncherError.gameCompatibility(
					"The official Bilibili platform helper is missing. Repair the game before launching."
				)
			}
			try fileManager.removeItem(at: paths.helper)
			try fileManager.moveItem(at: paths.original, to: paths.helper)
			return true
		}
		if !helperExists, originalExists {
			try fileManager.moveItem(at: paths.original, to: paths.helper)
			return true
		}
		return false
	}

	private func isLegacyShim(at url: URL) throws -> Bool {
		for marker in Self.launcherShimMarkers where try containsMarker(marker, at: url) {
			return true
		}
		return false
	}

	private func removeLegacyArtifacts(paths: Paths, fileManager: FileManager) throws -> Bool {
		var changed = false
		for (url, marker) in [
			(paths.bridge, Self.launcherBridgeMarker),
			(paths.injection, Self.launcherInjectionMarker),
		] {
			guard fileManager.fileExists(atPath: url.path),
				try containsMarker(marker, at: url)
			else { continue }
			try fileManager.removeItem(at: url)
			changed = true
		}
		return changed
	}

	private func removeOwnedLegacyStorage(paths: Paths, fileManager: FileManager) throws -> Bool {
		var changed = false
		if fileManager.fileExists(atPath: paths.original.path),
			fileManager.fileExists(atPath: paths.helper.path),
			try containsMarker(Self.officialHelperMarker, at: paths.original),
			try containsMarker(Self.officialHelperMarker, at: paths.helper)
		{
			try fileManager.removeItem(at: paths.original)
			changed = true
		}
		if browserLinkIsCurrent(paths, fileManager) {
			try fileManager.removeItem(at: paths.browserLink)
			changed = true
		}
		if fileManager.fileExists(atPath: paths.privateDirectory.path),
			try fileManager.contentsOfDirectory(atPath: paths.privateDirectory.path).isEmpty
		{
			try fileManager.removeItem(at: paths.privateDirectory)
			changed = true
		}
		return changed
	}

	private func validateOwnedController(paths: Paths, fileManager: FileManager) throws {
		guard fileManager.fileExists(atPath: paths.controller.path),
			try !containsMarker(Self.launcherControllerMarker, at: paths.controller)
		else { return }
		throw LauncherError.gameCompatibility(
			"The game directory contains an unknown Bilibili window controller.")
	}

	private func browserLinkIsCurrent(_ paths: Paths, _ fileManager: FileManager) -> Bool {
		(try? fileManager.destinationOfSymbolicLink(atPath: paths.browserLink.path))
			== "../\(Self.browserDirectoryName)"
	}

	private func containsMarker(_ marker: Data, at url: URL) throws -> Bool {
		try GameShimIO.containsMarker(
			at: url,
			marker: marker,
			maximumSize: AppConstants.Game.bilibiliPlatformAssetMaximumBytes
		)
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

	private func paths(in gameDirectory: URL) -> Paths {
		let directory = gameDirectory.appending(
			path: Self.helperDirectory, directoryHint: .isDirectory)
		let privateDirectory = directory.appending(
			path: Self.originalDirectoryName, directoryHint: .isDirectory)
		return Paths(
			directory: directory,
			privateDirectory: privateDirectory,
			helper: directory.appending(path: Self.helperName),
			controller: directory.appending(path: Self.controllerName),
			original: privateDirectory.appending(path: Self.helperName),
			browserLink: privateDirectory.appending(
				path: Self.browserDirectoryName, directoryHint: .isDirectory),
			injection: directory.appending(path: Self.injectionName),
			bridge: directory.appending(path: Self.bridgeName)
		)
	}

	private struct Paths {
		let directory: URL
		let privateDirectory: URL
		let helper: URL
		let controller: URL
		let original: URL
		let browserLink: URL
		let injection: URL
		let bridge: URL
	}
}
