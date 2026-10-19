// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation

@Test(arguments: [64, 1_733_632, 5 * 1_024 * 1_024])
func vuplexShimIsInstalledAndRestoredWithoutChangingTheOriginal(helperBytes: Int) throws {
	let fixture = try VuplexFixture()
	defer { fixture.remove() }
	let (root, helper) = (fixture.root, fixture.helper)
	var officialData = Data(repeating: 0, count: helperBytes)
	let marker = Data(VuplexCompatibility.compatibilityArgument.utf8)
	officialData.replaceSubrange((helperBytes - marker.count)..<helperBytes, with: marker)
	try officialData.write(to: helper)
	let shim = root.appending(path: "shim.exe")
	let shimData = Data("launcher-shim".utf8)
	try shimData.write(to: shim)

	let compatibility = try testCompatibility(shimURL: shim, root: root)
	#expect(try compatibility.installIfSupported(in: root))
	#expect(try Data(contentsOf: helper) == shimData)
	let installedUserenv = helper.deletingLastPathComponent().appending(
		path: VuplexCompatibility.userenvName)
	#expect(FileManager.default.fileExists(atPath: installedUserenv.path))

	let original = helper.deletingLastPathComponent().appending(
		path: VuplexCompatibility.originalHelperName)
	#expect(try Data(contentsOf: original) == officialData)
	#expect(try compatibility.restoreIfInstalled(in: root))
	#expect(try Data(contentsOf: helper) == officialData)
	#expect(!FileManager.default.fileExists(atPath: original.path))
	#expect(!FileManager.default.fileExists(atPath: installedUserenv.path))

	// An older shim upgrades in place and keeps the official helper; restore needs no bundled assets.
	try installedShimData().write(to: helper)
	try officialData.write(to: original)
	let newShim = root.appending(path: "new-shim.exe")
	let newShimData = Data("new-launcher-shim".utf8)
	try newShimData.write(to: newShim)
	let upgrade = try testCompatibility(shimURL: newShim, root: root)
	#expect(try upgrade.installIfSupported(in: root))
	#expect(try Data(contentsOf: helper) == newShimData)
	#expect(try Data(contentsOf: original) == officialData)

	try VuplexCompatibility.launcherShimMarker.write(to: helper)
	let withoutAssets = VuplexCompatibility(shimURL: nil, userenvURL: nil)
	#expect(try withoutAssets.restoreIfInstalled(in: root))
	#expect(try Data(contentsOf: helper) == officialData)
	#expect(!FileManager.default.fileExists(atPath: original.path))
	#expect(!FileManager.default.fileExists(atPath: installedUserenv.path))
}

@Test
func vuplexShimLeavesUnknownHelpersUntouched() throws {
	let shimData = Data("launcher-shim".utf8)
	let marker = Data(VuplexCompatibility.compatibilityArgument.utf8)
	var oversized = Data(repeating: 0, count: 5 * 1_024 * 1_024 + 1)
	oversized.replaceSubrange(0..<marker.count, with: marker)
	let official = Data("official-vx-accelerated-paint-disabled".utf8)

	// Unknown or oversized helpers are left alone and install reports no change.
	for helperData in [Data("unknown-helper".utf8), oversized] {
		let fixture = try VuplexFixture()
		defer { fixture.remove() }
		let compatibility = try fixture.compatibility(shimData: shimData)
		try helperData.write(to: fixture.helper)
		#expect(try !compatibility.installIfSupported(in: fixture.root))
		#expect(try Data(contentsOf: fixture.helper) == helperData)
	}

	// An unrelated userenv.dll blocks the install and stays in place.
	do {
		let fixture = try VuplexFixture()
		defer { fixture.remove() }
		let compatibility = try fixture.compatibility(shimData: shimData)
		try official.write(to: fixture.helper)
		let userenv = fixture.directory.appending(path: VuplexCompatibility.userenvName)
		let unknown = Data("unrelated-userenv".utf8)
		try unknown.write(to: userenv)
		#expect(throws: GameCompatibilityError.self) {
			try compatibility.installIfSupported(in: fixture.root)
		}
		#expect(try Data(contentsOf: fixture.helper) == official)
		#expect(try Data(contentsOf: userenv) == unknown)
	}

	// An older shim without its saved official helper cannot upgrade.
	do {
		let fixture = try VuplexFixture()
		defer { fixture.remove() }
		let compatibility = try fixture.compatibility(shimData: shimData)
		try installedShimData().write(to: fixture.helper)
		#expect(throws: GameCompatibilityError.self) {
			try compatibility.installIfSupported(in: fixture.root)
		}
	}

	// A helper replaced by the game updater is kept and the stale original is dropped.
	do {
		let fixture = try VuplexFixture()
		defer { fixture.remove() }
		let compatibility = try fixture.compatibility(shimData: shimData)
		let updated = Data("updated-vx-accelerated-paint-disabled".utf8)
		try updated.write(to: fixture.helper)
		let original = fixture.directory.appending(path: VuplexCompatibility.originalHelperName)
		try Data("old-helper".utf8).write(to: original)
		#expect(try !compatibility.restoreIfInstalled(in: fixture.root))
		#expect(try Data(contentsOf: fixture.helper) == updated)
		#expect(!FileManager.default.fileExists(atPath: original.path))
	}
}

private func installedShimData() -> Data {
	var data = Data()
	for value in [
		VuplexCompatibility.originalHelperName,
		"vx-accelerated-paint-disabled",
	] {
		for codeUnit in value.utf16 {
			data.append(UInt8(truncatingIfNeeded: codeUnit))
			data.append(UInt8(truncatingIfNeeded: codeUnit >> 8))
		}
	}
	return data
}

private struct VuplexFixture {
	let temporary: TemporaryDirectory
	let root: URL
	let helper: URL

	init() throws {
		temporary = try TemporaryDirectory("VuplexCompatibilityTests")
		root = temporary.url
		helper = root.appending(path: VuplexCompatibility.helperRelativePath)
		try FileManager.default.createDirectory(
			at: helper.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
	}

	var directory: URL { helper.deletingLastPathComponent() }

	func compatibility(shimData: Data) throws -> VuplexCompatibility {
		let shim = root.appending(path: "shim.exe")
		try shimData.write(to: shim)
		return try testCompatibility(shimURL: shim, root: root)
	}

	func remove() {
		temporary.remove()
	}
}

private func testCompatibility(shimURL: URL, root: URL) throws -> VuplexCompatibility {
	let userenvURL = root.appending(path: "bundled-userenv.dll")
	try Data("Arknights Client AppContainer compatibility".utf8).write(to: userenvURL)
	return VuplexCompatibility(shimURL: shimURL, userenvURL: userenvURL)
}
