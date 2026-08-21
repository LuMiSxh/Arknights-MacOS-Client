// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func platformProcessComponentInstallsAndRestoresOfficialHelper() throws {
	let fixture = try PlatformProcessFixture()
	defer { fixture.remove() }
	let official = Data("official PlatformProcess.exe".utf8)
	try official.write(to: fixture.helper)

	#expect(try fixture.component.installIfSupported(in: fixture.root))
	#expect(try Data(contentsOf: fixture.helper) == fixture.shimData)
	#expect(try Data(contentsOf: fixture.original) == official)
	#expect(try Data(contentsOf: fixture.installedBridge) == fixture.bridgeData)

	#expect(try fixture.component.restoreIfInstalled(in: fixture.root))
	#expect(try Data(contentsOf: fixture.helper) == official)
	#expect(!FileManager.default.fileExists(atPath: fixture.original.path))
	#expect(!FileManager.default.fileExists(atPath: fixture.installedBridge.path))
}

@Test
func platformProcessComponentIsIdempotent() throws {
	let fixture = try PlatformProcessFixture()
	defer { fixture.remove() }
	try Data("official PlatformProcess.exe".utf8).write(to: fixture.helper)

	#expect(try fixture.component.installIfSupported(in: fixture.root))
	#expect(try !fixture.component.installIfSupported(in: fixture.root))
}

@Test
func platformProcessComponentLeavesUnknownHelperUntouched() throws {
	let fixture = try PlatformProcessFixture()
	defer { fixture.remove() }
	let unknown = Data("unrelated executable".utf8)
	try unknown.write(to: fixture.helper)

	#expect(try !fixture.component.installIfSupported(in: fixture.root))
	#expect(try Data(contentsOf: fixture.helper) == unknown)
}

@Test
func platformProcessComponentRejectsUnknownBridge() throws {
	let fixture = try PlatformProcessFixture()
	defer { fixture.remove() }
	try Data("official PlatformProcess.exe".utf8).write(to: fixture.helper)
	let unknownBridge = Data("unrelated dynamic library".utf8)
	try unknownBridge.write(to: fixture.installedBridge)

	#expect(throws: LauncherError.self) {
		try fixture.component.installIfSupported(in: fixture.root)
	}
	#expect(try Data(contentsOf: fixture.installedBridge) == unknownBridge)
}

@Test
func platformProcessComponentUpgradePreservesOfficialHelper() throws {
	let fixture = try PlatformProcessFixture()
	defer { fixture.remove() }
	let official = Data("official PlatformProcess.exe".utf8)
	try official.write(to: fixture.original)
	try Data("old Arknights Client PlatformProcess compatibility".utf8).write(
		to: fixture.helper)
	try Data("old Arknights Client PlatformProcess window bridge".utf8).write(
		to: fixture.installedBridge)

	#expect(try fixture.component.installIfSupported(in: fixture.root))
	#expect(try Data(contentsOf: fixture.original) == official)
	#expect(try Data(contentsOf: fixture.helper) == fixture.shimData)
	#expect(try Data(contentsOf: fixture.installedBridge) == fixture.bridgeData)
}

@Test
func platformProcessComponentAcceptsOfficialUpdaterReplacement() throws {
	let fixture = try PlatformProcessFixture()
	defer { fixture.remove() }
	let oldOfficial = Data("old official PlatformProcess.exe".utf8)
	let updatedOfficial = Data("updated official PlatformProcess.exe".utf8)
	try oldOfficial.write(to: fixture.original)
	try updatedOfficial.write(to: fixture.helper)
	try fixture.bridgeData.write(to: fixture.installedBridge)

	#expect(try fixture.component.installIfSupported(in: fixture.root))
	#expect(try Data(contentsOf: fixture.original) == updatedOfficial)
	#expect(try Data(contentsOf: fixture.helper) == fixture.shimData)
}

@Test
func platformProcessComponentRestoresWithoutBundledAssets() throws {
	let fixture = try PlatformProcessFixture()
	defer { fixture.remove() }
	let official = Data("official PlatformProcess.exe".utf8)
	try official.write(to: fixture.original)
	try fixture.shimData.write(to: fixture.helper)
	try fixture.bridgeData.write(to: fixture.installedBridge)
	let compatibility = PlatformProcessCompatibility(shimURL: nil, bridgeURL: nil)

	#expect(try compatibility.restoreIfInstalled(in: fixture.root))
	#expect(try Data(contentsOf: fixture.helper) == official)
	#expect(!FileManager.default.fileExists(atPath: fixture.installedBridge.path))
}

private struct PlatformProcessFixture {
	let root: URL
	let helper: URL
	let original: URL
	let installedBridge: URL
	let shimData = Data("Arknights Client PlatformProcess compatibility".utf8)
	let bridgeData = Data("Arknights Client PlatformProcess window bridge".utf8)
	let component: PlatformProcessCompatibility

	init() throws {
		root = FileManager.default.temporaryDirectory.appending(
			path: UUID().uuidString,
			directoryHint: .isDirectory
		)
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		helper = root.appending(path: PlatformProcessCompatibility.helperRelativePath)
		original = root.appending(path: PlatformProcessCompatibility.originalHelperName)
		installedBridge = root.appending(path: PlatformProcessCompatibility.bridgeName)
		let shim = root.appending(path: "bundled-platform-process.exe")
		let bridge = root.appending(path: "bundled-platform-process-bridge.dylib")
		try shimData.write(to: shim)
		try bridgeData.write(to: bridge)
		component = PlatformProcessCompatibility(shimURL: shim, bridgeURL: bridge)
	}

	func remove() {
		try? FileManager.default.removeItem(at: root)
	}
}
