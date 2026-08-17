// SPDX-License-Identifier: MPL-2.0

import Foundation

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
		logsDirectory: URL = AppPaths().logRoot,
		fileManager: FileManager = .default,
		userName: String = NSUserName()
	) throws {
		let dosDevices = prefixDirectory.appending(path: "dosdevices", directoryHint: .isDirectory)
		try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

		for device in try fileManager.contentsOfDirectory(
			at: dosDevices,
			includingPropertiesForKeys: nil
		) {
			let name = device.lastPathComponent.lowercased()
			guard name != "c:" else { continue }
			if name == "g:",
				symbolicLink(at: device, pointsTo: gameDirectory, fileManager: fileManager)
			{
				continue
			}
			if name == "l:",
				symbolicLink(at: device, pointsTo: logsDirectory, fileManager: fileManager)
			{
				continue
			}
			try fileManager.removeItem(at: device)
		}

		let gameDrive = dosDevices.appending(path: "g:")
		if !symbolicLink(at: gameDrive, pointsTo: gameDirectory, fileManager: fileManager) {
			try? fileManager.removeItem(at: gameDrive)
			try fileManager.createSymbolicLink(at: gameDrive, withDestinationURL: gameDirectory)
		}

		let logDrive = dosDevices.appending(path: "l:")
		if !symbolicLink(at: logDrive, pointsTo: logsDirectory, fileManager: fileManager) {
			try? fileManager.removeItem(at: logDrive)
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
				if (try? fileManager.destinationOfSymbolicLink(atPath: folder.path)) != nil {
					try fileManager.removeItem(at: folder)
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
	) -> Bool {
		guard let current = try? fileManager.destinationOfSymbolicLink(atPath: link.path) else {
			return false
		}
		let currentURL =
			current.hasPrefix("/")
			? URL(filePath: current)
			: link.deletingLastPathComponent().appending(path: current)
		return currentURL.standardizedFileURL.path == destination.standardizedFileURL.path
	}
}
