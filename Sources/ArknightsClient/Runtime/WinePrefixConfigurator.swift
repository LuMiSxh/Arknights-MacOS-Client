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
			guard device.lastPathComponent.lowercased() != "c:" else { continue }
			try fileManager.removeItem(at: device)
		}

		let gameDrive = dosDevices.appending(path: "g:")
		try fileManager.createSymbolicLink(at: gameDrive, withDestinationURL: gameDirectory)

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
}
