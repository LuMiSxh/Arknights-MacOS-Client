// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func bilibiliPlatformComponentMigratesLegacyWrapperAndInstallsController() throws {
	let fixture = try BilibiliPlatformFixture(legacyWrapper: true)
	defer { fixture.remove() }

	#expect(try fixture.component.installIfSupported(in: fixture.root))
	#expect(try Data(contentsOf: fixture.helper) == fixture.officialData)
	#expect(try Data(contentsOf: fixture.installedController) == fixture.controllerData)
	#expect(!FileManager.default.fileExists(atPath: fixture.privateDirectory.path))
	#expect(!FileManager.default.fileExists(atPath: fixture.installedBridge.path))
	#expect(!FileManager.default.fileExists(atPath: fixture.installedInjection.path))
	#expect(try !fixture.component.installIfSupported(in: fixture.root))

	#expect(try fixture.component.restoreIfInstalled(in: fixture.root))
	#expect(try Data(contentsOf: fixture.helper) == fixture.officialData)
	#expect(!FileManager.default.fileExists(atPath: fixture.installedController.path))
	#expect(try !fixture.component.restoreIfInstalled(in: fixture.root))
}

@Test
func bilibiliPlatformComponentPreservesUnknownFilesDuringLegacyMigration() throws {
	let fixture = try BilibiliPlatformFixture(legacyWrapper: true, unknownPrivateFile: true)
	defer { fixture.remove() }
	let unknown = Data("user-owned Bilibili file".utf8)
	try unknown.write(to: fixture.unknownPrivateFile)

	#expect(try fixture.component.installIfSupported(in: fixture.root))
	#expect(try Data(contentsOf: fixture.helper) == fixture.officialData)
	#expect(try Data(contentsOf: fixture.unknownPrivateFile) == unknown)
	#expect(FileManager.default.fileExists(atPath: fixture.privateDirectory.path))
}

@Test
func bilibiliPlatformComponentLeavesUnknownHelperAndControllerUntouched() throws {
	let fixture = try BilibiliPlatformFixture()
	defer { fixture.remove() }
	let unknownHelper = Data("unrelated executable".utf8)
	let unknownController = Data("unrelated controller".utf8)
	try unknownHelper.write(to: fixture.helper)
	try unknownController.write(to: fixture.installedController)

	#expect(try !fixture.component.installIfSupported(in: fixture.root))
	#expect(try Data(contentsOf: fixture.helper) == unknownHelper)
	#expect(try Data(contentsOf: fixture.installedController) == unknownController)
}

private struct BilibiliPlatformFixture {
	let root: URL
	let helper: URL
	let privateDirectory: URL
	let officialHelper: URL
	let unknownPrivateFile: URL
	let installedController: URL
	let installedBridge: URL
	let installedInjection: URL
	let officialData = Data("official PCGamePlatform.exe".utf8)
	let controllerData = Data("Arknights Client Bilibili window controller".utf8)
	let component: BilibiliPlatformCompatibility

	init(legacyWrapper: Bool = false, unknownPrivateFile: Bool = false) throws {
		root = FileManager.default.temporaryDirectory.appending(
			path: UUID().uuidString, directoryHint: .isDirectory)
		let directory = root.appending(path: "BLPlatform64", directoryHint: .isDirectory)
		privateDirectory = directory.appending(
			path: BilibiliPlatformCompatibility.originalDirectoryName,
			directoryHint: .isDirectory
		)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(
			at: directory.appending(path: BilibiliPlatformCompatibility.browserDirectoryName),
			withIntermediateDirectories: true
		)
		helper = directory.appending(path: BilibiliPlatformCompatibility.helperName)
		officialHelper = privateDirectory.appending(
			path: BilibiliPlatformCompatibility.helperName)
		self.unknownPrivateFile = privateDirectory.appending(path: "user-file")
		installedController = directory.appending(
			path: BilibiliPlatformCompatibility.controllerName)
		installedBridge = directory.appending(
			path: BilibiliPlatformCompatibility.bridgeName)
		installedInjection = directory.appending(
			path: BilibiliPlatformCompatibility.injectionName)
		let bundledController = root.appending(path: "bundled-controller.exe")
		try controllerData.write(to: bundledController)
		component = BilibiliPlatformCompatibility(controllerURL: bundledController)
		if legacyWrapper {
			try Data("Arknights Client Bilibili platform compatibility".utf8).write(to: helper)
			try FileManager.default.createDirectory(
				at: privateDirectory, withIntermediateDirectories: true)
			try officialData.write(to: officialHelper)
			try FileManager.default.createSymbolicLink(
				atPath:
					privateDirectory
					.appending(path: BilibiliPlatformCompatibility.browserDirectoryName).path,
				withDestinationPath: "../\(BilibiliPlatformCompatibility.browserDirectoryName)"
			)
			try Data("Arknights Client Bilibili platform window bridge".utf8).write(
				to: installedBridge)
			try Data("Arknights Client Bilibili platform injection selector".utf8).write(
				to: installedInjection)
		} else {
			try officialData.write(to: helper)
		}
		if unknownPrivateFile {
			try FileManager.default.createDirectory(
				at: privateDirectory, withIntermediateDirectories: true)
		}
	}

	func remove() {
		try? FileManager.default.removeItem(at: root)
	}
}
