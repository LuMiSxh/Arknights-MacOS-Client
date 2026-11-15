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

	let compatibility = VuplexCompatibility(shimURL: shim)
	#expect(try compatibility.installIfSupported(in: root))
	#expect(try Data(contentsOf: helper) == shimData)

	let original = helper.deletingLastPathComponent().appending(
		path: VuplexCompatibility.originalHelperName)
	#expect(try Data(contentsOf: original) == officialData)
	#expect(try compatibility.restoreIfInstalled(in: root))
	#expect(try Data(contentsOf: helper) == officialData)
	#expect(!FileManager.default.fileExists(atPath: original.path))

	// An older shim upgrades in place and keeps the official helper; restore needs no bundled assets.
	try installedShimData().write(to: helper)
	try officialData.write(to: original)
	let newShim = root.appending(path: "new-shim.exe")
	let newShimData = Data("new-launcher-shim".utf8)
	try newShimData.write(to: newShim)
	let upgrade = VuplexCompatibility(shimURL: newShim)
	#expect(try upgrade.installIfSupported(in: root))
	#expect(try Data(contentsOf: helper) == newShimData)
	#expect(try Data(contentsOf: original) == officialData)

	try VuplexCompatibility.launcherShimMarker.write(to: helper)
	let withoutAssets = VuplexCompatibility(shimURL: nil)
	#expect(try withoutAssets.restoreIfInstalled(in: root))
	#expect(try Data(contentsOf: helper) == officialData)
	#expect(!FileManager.default.fileExists(atPath: original.path))
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

	func remove() {
		temporary.remove()
	}
}
