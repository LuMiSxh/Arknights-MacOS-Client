// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

/// Installs the Bilibili login-window controller without replacing Bilibili's platform helper.
package struct BilibiliPlatformCompatibility: GameCompatibilityComponent {
	let identifier = "bilibili-platform"
	static let helperDirectory = "BLPlatform64"
	static let helperName = "PCGamePlatform.exe"
	package static let controllerName = "BilibiliWindowController.exe"
	static let launcherControllerMarker = Data(
		"Arknights Client Bilibili window controller".utf8)
	private static let officialHelperMarker = Data("PCGamePlatform.exe".utf8)
	private static let temporaryPrefix = ".arknights-client-bilibili-platform-"

	private let controllerURL: URL?
	private let log: LauncherLog?

	init(bundle: Bundle = .main, log: LauncherLog? = nil) {
		self.log = log
		let directory = bundle.resourceURL.map(BundledResource.compatibility.location)?
			.appending(path: "BilibiliPlatform", directoryHint: .isDirectory)
		controllerURL = directory?.appending(path: Self.controllerName)
	}

	init(controllerURL: URL?, log: LauncherLog? = nil) {
		self.controllerURL = controllerURL
		self.log = log
	}

	@discardableResult
	func installIfSupported(
		in gameDirectory: URL,
		fileManager: FileManager = .default
	) throws -> Bool {
		let paths = paths(in: gameDirectory)
		try removeTemporaryFiles(in: paths.directory, fileManager: fileManager)
		guard let controllerURL,
			fileManager.fileExists(atPath: controllerURL.path),
			fileManager.fileExists(atPath: paths.helper.path)
		else { return false }

		guard try containsMarker(Self.officialHelperMarker, at: paths.helper) else {
			return false
		}
		try validateOwnedController(paths: paths, fileManager: fileManager)
		let controllerMatches = fileManager.contentsEqual(
			atPath: paths.controller.path, andPath: controllerURL.path)
		guard !controllerMatches else { return false }

		let stagedController = temporaryURL(in: paths.directory, suffix: "controller")
		let previousController = temporaryURL(in: paths.directory, suffix: "previous-controller")
		defer {
			GameShimIO.removeIfPresent(
				"Could not remove the staged Bilibili controller",
				at: stagedController,
				fileManager: fileManager,
				log: log
			)
			GameShimIO.removeIfPresent(
				"Could not remove the previous Bilibili controller",
				at: previousController,
				fileManager: fileManager,
				log: log
			)
		}
		try fileManager.copyItem(at: controllerURL, to: stagedController)
		if fileManager.fileExists(atPath: paths.controller.path) {
			try fileManager.moveItem(at: paths.controller, to: previousController)
		}
		do {
			try fileManager.moveItem(at: stagedController, to: paths.controller)
			GameShimIO.removeIfPresent(
				"Could not remove the previous Bilibili controller",
				at: previousController,
				fileManager: fileManager,
				log: log
			)
		} catch {
			try GameShimIO.rethrowAfterRollback(
				error,
				steps: [
					{
						if fileManager.fileExists(atPath: paths.controller.path) {
							try fileManager.removeItem(at: paths.controller)
						}
					},
					{
						if fileManager.fileExists(atPath: previousController.path) {
							try fileManager.moveItem(at: previousController, to: paths.controller)
						}
					},
				]
			)
		}
		return true
	}

	@discardableResult
	func restoreIfInstalled(
		in gameDirectory: URL,
		fileManager: FileManager = .default
	) throws -> Bool {
		let paths = paths(in: gameDirectory)
		try removeTemporaryFiles(in: paths.directory, fileManager: fileManager)
		guard fileManager.fileExists(atPath: paths.controller.path),
			try containsMarker(Self.launcherControllerMarker, at: paths.controller)
		else { return false }
		try fileManager.removeItem(at: paths.controller)
		return true
	}

	private func validateOwnedController(paths: Paths, fileManager: FileManager) throws {
		guard fileManager.fileExists(atPath: paths.controller.path),
			try !containsMarker(Self.launcherControllerMarker, at: paths.controller)
		else { return }
		throw GameCompatibilityError.setupFailed(
			"The game directory contains an unknown Bilibili window controller.")
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
		return Paths(
			directory: directory,
			helper: directory.appending(path: Self.helperName),
			controller: directory.appending(path: Self.controllerName)
		)
	}

	private struct Paths {
		let directory: URL
		let helper: URL
		let controller: URL
	}
}
