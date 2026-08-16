// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func winePrefixUsesOnlyIsolatedFoldersAndGameDrive() throws {
	let fileManager = FileManager.default
	let root = fileManager.temporaryDirectory.appending(
		path: "arknights-prefix-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: root) }

	let prefix = root.appending(path: "prefix", directoryHint: .isDirectory)
	let dosDevices = prefix.appending(path: "dosdevices", directoryHint: .isDirectory)
	let userDirectory = prefix.appending(
		path: "drive_c/users/tester",
		directoryHint: .isDirectory
	)
	let crossoverUserDirectory = prefix.appending(
		path: "drive_c/users/crossover",
		directoryHint: .isDirectory
	)
	let hostDocuments = root.appending(path: "Host Documents", directoryHint: .isDirectory)
	let gameDirectory = root.appending(path: "Game", directoryHint: .isDirectory)
	try fileManager.createDirectory(at: dosDevices, withIntermediateDirectories: true)
	try fileManager.createDirectory(at: userDirectory, withIntermediateDirectories: true)
	try fileManager.createDirectory(
		at: crossoverUserDirectory,
		withIntermediateDirectories: true
	)
	try fileManager.createDirectory(at: hostDocuments, withIntermediateDirectories: true)
	try fileManager.createDirectory(at: gameDirectory, withIntermediateDirectories: true)
	try fileManager.createSymbolicLink(
		at: dosDevices.appending(path: "c:"),
		withDestinationURL: prefix.appending(path: "drive_c")
	)
	try fileManager.createSymbolicLink(
		at: dosDevices.appending(path: "z:"),
		withDestinationURL: URL(filePath: "/")
	)
	try Data("host mapping".utf8).write(to: dosDevices.appending(path: "h:"))
	try fileManager.createSymbolicLink(
		at: userDirectory.appending(path: "Documents"),
		withDestinationURL: hostDocuments
	)
	try fileManager.createSymbolicLink(
		at: crossoverUserDirectory.appending(path: "Downloads"),
		withDestinationURL: hostDocuments
	)

	try WinePrefixConfigurator().configure(
		prefixDirectory: prefix,
		gameDirectory: gameDirectory,
		userName: "tester"
	)
	let gameDrive = dosDevices.appending(path: "g:")
	let originalFileNumber =
		try fileManager.attributesOfItem(atPath: gameDrive.path)[
			.systemFileNumber
		] as? NSNumber
	try WinePrefixConfigurator().configure(
		prefixDirectory: prefix,
		gameDirectory: gameDirectory,
		userName: "tester"
	)
	let preservedFileNumber =
		try fileManager.attributesOfItem(atPath: gameDrive.path)[
			.systemFileNumber
		] as? NSNumber

	#expect(fileManager.fileExists(atPath: dosDevices.appending(path: "c:").path))
	#expect(preservedFileNumber == originalFileNumber)
	#expect(!fileManager.fileExists(atPath: dosDevices.appending(path: "z:").path))
	#expect(!fileManager.fileExists(atPath: dosDevices.appending(path: "h:").path))
	#expect(
		try fileManager.destinationOfSymbolicLink(
			atPath: dosDevices.appending(path: "g:").path
		) == gameDirectory.path
	)
	for profileDirectory in [userDirectory, crossoverUserDirectory] {
		for folderName in ["Desktop", "Documents", "Downloads", "Music", "Pictures", "Videos"] {
			let folder = profileDirectory.appending(
				path: folderName,
				directoryHint: .isDirectory
			)
			#expect(fileManager.fileExists(atPath: folder.path))
			#expect((try? fileManager.destinationOfSymbolicLink(atPath: folder.path)) == nil)
		}
	}
}

@Test
func winePrefixPreservesFilesInsideItsIsolatedFolders() throws {
	let fileManager = FileManager.default
	let root = fileManager.temporaryDirectory.appending(
		path: "arknights-prefix-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: root) }

	let prefix = root.appending(path: "prefix", directoryHint: .isDirectory)
	let documents = prefix.appending(
		path: "drive_c/users/tester/Documents",
		directoryHint: .isDirectory
	)
	let gameDirectory = root.appending(path: "Game", directoryHint: .isDirectory)
	try fileManager.createDirectory(
		at: prefix.appending(path: "dosdevices", directoryHint: .isDirectory),
		withIntermediateDirectories: true
	)
	try fileManager.createDirectory(at: documents, withIntermediateDirectories: true)
	try fileManager.createDirectory(at: gameDirectory, withIntermediateDirectories: true)
	let savedFile = documents.appending(path: "saved.txt")
	try Data("saved".utf8).write(to: savedFile)

	try WinePrefixConfigurator().configure(
		prefixDirectory: prefix,
		gameDirectory: gameDirectory,
		userName: "tester"
	)

	#expect(fileManager.fileExists(atPath: savedFile.path))
}
