// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

/// Points the prefix's `G:` drive at the active region's game directory and isolates
/// Wine's shell folders, so this Windows environment never touches the user's real files.
struct WinePrefixConfigurator {
	// Wine defaults these to symlinks into the real macOS home folder. Replacing them with
	// plain empty directories keeps the game and its Windows apps from ever seeing (or
	// writing into) the user's actual Desktop/Documents/etc.
	private let isolatedShellFolders = [
		"Desktop", "Documents", "Downloads", "Music", "Pictures", "Videos",
	]

	func configure(
		prefixDirectory: URL,
		gameDirectory: URL,
		logsDirectory: URL,
		fileManager: FileManager = .default,
		userName: String = NSUserName()
	) throws {
		let dosDevices = prefixDirectory.appending(path: "dosdevices", directoryHint: .isDirectory)
		try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
		for device in try fileManager.contentsOfDirectory(
			at: dosDevices, includingPropertiesForKeys: nil
		) {
			let name = device.lastPathComponent.lowercased()
			guard name != "c:" else { continue }
			if name == "g:",
				try symbolicLink(at: device, pointsTo: gameDirectory, fileManager: fileManager)
			{
				continue
			}
			if name == "l:",
				try symbolicLink(at: device, pointsTo: logsDirectory, fileManager: fileManager)
			{
				continue
			}
			try fileManager.removeItem(at: device)
		}

		let gameDrive = dosDevices.appending(path: "g:")
		if try !symbolicLink(at: gameDrive, pointsTo: gameDirectory, fileManager: fileManager) {
			try removeItemIfPresent(at: gameDrive, fileManager: fileManager)
			try fileManager.createSymbolicLink(at: gameDrive, withDestinationURL: gameDirectory)
		}

		let logDrive = dosDevices.appending(path: "l:")
		if try !symbolicLink(at: logDrive, pointsTo: logsDirectory, fileManager: fileManager) {
			try removeItemIfPresent(at: logDrive, fileManager: fileManager)
			try fileManager.createSymbolicLink(at: logDrive, withDestinationURL: logsDirectory)
		}

		let usersDirectory = prefixDirectory.appending(
			path: "drive_c/users",
			directoryHint: .isDirectory
		)
		// The runtime's own prefix seeding sometimes creates a "crossover" profile
		// regardless of the host username, so both are isolated to be safe.
		for profileName in Set([userName, "crossover"]) {
			let userDirectory = usersDirectory.appending(
				path: profileName,
				directoryHint: .isDirectory
			)
			for folderName in isolatedShellFolders {
				let folder = userDirectory.appending(
					path: folderName,
					directoryHint: .isDirectory
				)
				do {
					_ = try fileManager.destinationOfSymbolicLink(atPath: folder.path)
					try fileManager.removeItem(at: folder)
				} catch {
					guard Self.isMissingOrNotSymbolicLink(error) else { throw error }
					// The folder is absent or already a regular directory.
				}
				if !fileManager.fileExists(atPath: folder.path) {
					try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
				}
			}
		}
	}

	private func symbolicLink(
		at link: URL,
		pointsTo destination: URL,
		fileManager: FileManager
	) throws -> Bool {
		let current: String
		do {
			current = try fileManager.destinationOfSymbolicLink(atPath: link.path)
		} catch {
			guard Self.isMissingOrNotSymbolicLink(error) else { throw error }
			return false
		}
		let currentURL =
			current.hasPrefix("/")
			? URL(filePath: current)
			: link.deletingLastPathComponent().appending(path: current)
		return currentURL.standardizedFileURL.path == destination.standardizedFileURL.path
	}

	private func removeItemIfPresent(at url: URL, fileManager: FileManager) throws {
		do {
			_ = try fileManager.attributesOfItem(atPath: url.path)
			try fileManager.removeItem(at: url)
		} catch let error as CocoaError
			where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile
		{
			return
		}
	}

	private static func isMissingOrNotSymbolicLink(_ error: any Error) -> Bool {
		var current: NSError? = error as NSError
		while let candidate = current {
			let posix =
				candidate.domain == NSPOSIXErrorDomain
				&& (candidate.code == Int(EINVAL) || candidate.code == Int(ENOENT))
			let cocoa =
				candidate.domain == NSCocoaErrorDomain
				&& (candidate.code == CocoaError.fileNoSuchFile.rawValue
					|| candidate.code == CocoaError.fileReadNoSuchFile.rawValue)
			if posix || cocoa { return true }
			current = candidate.userInfo[NSUnderlyingErrorKey] as? NSError
		}
		return false
	}
}
