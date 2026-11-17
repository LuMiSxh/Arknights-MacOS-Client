// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation

@Test
func bilibiliPlatformComponentInstallsAndRestoresItsController() throws {
	let fixture = try BilibiliPlatformFixture(
		existingController: Data("Arknights Client Bilibili window controller v0".utf8))
	defer { fixture.remove() }

	#expect(try fixture.component.installIfSupported(in: fixture.root))
	#expect(try Data(contentsOf: fixture.installedController) == fixture.controllerData)
	#expect(try !fixture.component.installIfSupported(in: fixture.root))

	#expect(try fixture.component.restoreIfInstalled(in: fixture.root))
	#expect(!FileManager.default.fileExists(atPath: fixture.installedController.path))
	#expect(try !fixture.component.restoreIfInstalled(in: fixture.root))
	#expect(try Data(contentsOf: fixture.helper) == fixture.officialData)
}

@Test
func bilibiliPlatformComponentLeavesUnknownFilesAlone() throws {
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
	let temporary: TemporaryDirectory
	let root: URL
	let helper: URL
	let installedController: URL
	let officialData = Data("official PCGamePlatform.exe".utf8)
	let controllerData = Data("Arknights Client Bilibili window controller".utf8)
	let component: BilibiliPlatformCompatibility

	init(existingController: Data? = nil) throws {
		temporary = try TemporaryDirectory("BilibiliPlatformCompatibilityTests")
		root = temporary.url
		let directory = root.appending(path: "BLPlatform64", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		helper = directory.appending(path: BilibiliPlatformCompatibility.helperName)
		installedController = directory.appending(
			path: BilibiliPlatformCompatibility.controllerName)
		let bundledController = root.appending(path: "bundled-controller.exe")
		try controllerData.write(to: bundledController)
		component = BilibiliPlatformCompatibility(controllerURL: bundledController)
		try officialData.write(to: helper)
		if let existingController {
			try existingController.write(to: installedController)
		}
	}

	func remove() {
		temporary.remove()
	}
}
