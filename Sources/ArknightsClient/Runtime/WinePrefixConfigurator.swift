// SPDX-License-Identifier: MPL-2.0

import Foundation

struct WinePrefixConfigurator {
	private let isolatedShellFolders = [
		"Desktop", "Documents", "Downloads", "Music", "Pictures", "Videos",
	]

	func configure(
		prefixDirectory: URL,
		gameDirectory: URL,
		fileManager: FileManager = .default,
		userName: String = NSUserName()
	) throws {
		let dosDevices = prefixDirectory.appending(path: "dosdevices", directoryHint: .isDirectory)
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
			try fileManager.removeItem(at: device)
		}

		let gameDrive = dosDevices.appending(path: "g:")
		if !symbolicLink(at: gameDrive, pointsTo: gameDirectory, fileManager: fileManager) {
			try fileManager.createSymbolicLink(at: gameDrive, withDestinationURL: gameDirectory)
		}

		let usersDirectory = prefixDirectory.appending(
			path: "drive_c/users",
			directoryHint: .isDirectory
		)
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
