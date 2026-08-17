// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func vuplexShimIsInstalledAndRestoredWithoutChangingTheOriginal() throws {
	let root = FileManager.default.temporaryDirectory.appending(
		path: UUID().uuidString,
		directoryHint: .isDirectory
	)
	defer { try? FileManager.default.removeItem(at: root) }
	let helper = root.appending(path: VuplexCompatibility.helperRelativePath)
	try FileManager.default.createDirectory(
		at: helper.deletingLastPathComponent(),
		withIntermediateDirectories: true
	)
	let officialData = Data("official-vx-accelerated-paint-disabled".utf8)
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
}

@Test
func vuplexShimLeavesUnknownHelpersUntouched() throws {
	let root = FileManager.default.temporaryDirectory.appending(
		path: UUID().uuidString,
		directoryHint: .isDirectory
	)
	defer { try? FileManager.default.removeItem(at: root) }
	let helper = root.appending(path: VuplexCompatibility.helperRelativePath)
	try FileManager.default.createDirectory(
		at: helper.deletingLastPathComponent(),
		withIntermediateDirectories: true
	)
	let officialData = Data("unknown-helper".utf8)
	try officialData.write(to: helper)
	let shim = root.appending(path: "shim.exe")
	try Data("launcher-shim".utf8).write(to: shim)

	let compatibility = try testCompatibility(shimURL: shim, root: root)
	#expect(try !compatibility.installIfSupported(in: root))
	#expect(try Data(contentsOf: helper) == officialData)
}

@Test
func vuplexShimDoesNotReplaceAnUnknownUserenvDLL() throws {
	let root = FileManager.default.temporaryDirectory.appending(
		path: UUID().uuidString,
		directoryHint: .isDirectory
	)
	defer { try? FileManager.default.removeItem(at: root) }
	let helper = root.appending(path: VuplexCompatibility.helperRelativePath)
	try FileManager.default.createDirectory(
		at: helper.deletingLastPathComponent(),
		withIntermediateDirectories: true
	)
	let officialData = Data("official-vx-accelerated-paint-disabled".utf8)
	try officialData.write(to: helper)
	let unknownUserenv = helper.deletingLastPathComponent().appending(
		path: VuplexCompatibility.userenvName)
	let unknownData = Data("unrelated-userenv".utf8)
	try unknownData.write(to: unknownUserenv)
	let shim = root.appending(path: "shim.exe")
	try Data("launcher-shim".utf8).write(to: shim)
	let compatibility = try testCompatibility(shimURL: shim, root: root)

	#expect(throws: LauncherError.self) {
		try compatibility.installIfSupported(in: root)
	}
	#expect(try Data(contentsOf: helper) == officialData)
	#expect(try Data(contentsOf: unknownUserenv) == unknownData)
}

@Test
func vuplexRestoreKeepsAnUpdaterReplacement() throws {
	let root = FileManager.default.temporaryDirectory.appending(
		path: UUID().uuidString,
		directoryHint: .isDirectory
	)
	defer { try? FileManager.default.removeItem(at: root) }
	let helper = root.appending(path: VuplexCompatibility.helperRelativePath)
	try FileManager.default.createDirectory(
		at: helper.deletingLastPathComponent(),
		withIntermediateDirectories: true
	)
	let updatedData = Data("updated-vx-accelerated-paint-disabled".utf8)
	try updatedData.write(to: helper)
	let original = helper.deletingLastPathComponent().appending(
		path: VuplexCompatibility.originalHelperName)
	try Data("old-helper".utf8).write(to: original)
	let shim = root.appending(path: "shim.exe")
	try Data("launcher-shim".utf8).write(to: shim)

	let compatibility = try testCompatibility(shimURL: shim, root: root)
	#expect(try !compatibility.restoreIfInstalled(in: root))
	#expect(try Data(contentsOf: helper) == updatedData)
	#expect(!FileManager.default.fileExists(atPath: original.path))
}

@Test
func vuplexShimUpgradePreservesTheOfficialHelper() throws {
	let root = FileManager.default.temporaryDirectory.appending(
		path: UUID().uuidString,
		directoryHint: .isDirectory
	)
	defer { try? FileManager.default.removeItem(at: root) }
	let helper = root.appending(path: VuplexCompatibility.helperRelativePath)
	try FileManager.default.createDirectory(
		at: helper.deletingLastPathComponent(),
		withIntermediateDirectories: true
	)
	try installedShimData().write(to: helper)
	let original = helper.deletingLastPathComponent().appending(
		path: VuplexCompatibility.originalHelperName)
	let officialData = Data("official-vx-accelerated-paint-disabled".utf8)
	try officialData.write(to: original)
	let newShim = root.appending(path: "new-shim.exe")
	let newShimData = Data("new-launcher-shim".utf8)
	try newShimData.write(to: newShim)

	let compatibility = try testCompatibility(shimURL: newShim, root: root)
	#expect(try compatibility.installIfSupported(in: root))
	#expect(try Data(contentsOf: helper) == newShimData)
	#expect(try Data(contentsOf: original) == officialData)
}

@Test
func vuplexShimUpgradeRejectsAMissingOfficialHelper() throws {
	let root = FileManager.default.temporaryDirectory.appending(
		path: UUID().uuidString,
		directoryHint: .isDirectory
	)
	defer { try? FileManager.default.removeItem(at: root) }
	let helper = root.appending(path: VuplexCompatibility.helperRelativePath)
	try FileManager.default.createDirectory(
		at: helper.deletingLastPathComponent(),
		withIntermediateDirectories: true
	)
	try installedShimData().write(to: helper)
	let newShim = root.appending(path: "new-shim.exe")
	try Data("new-launcher-shim".utf8).write(to: newShim)

	let compatibility = try testCompatibility(shimURL: newShim, root: root)
	#expect(throws: LauncherError.self) {
		try compatibility.installIfSupported(in: root)
	}
}

@Test
func vuplexRestoreWorksWithoutBundledCompatibilityAssets() throws {
	let root = FileManager.default.temporaryDirectory.appending(
		path: UUID().uuidString,
		directoryHint: .isDirectory
	)
	defer { try? FileManager.default.removeItem(at: root) }
	let helper = root.appending(path: VuplexCompatibility.helperRelativePath)
	try FileManager.default.createDirectory(
		at: helper.deletingLastPathComponent(),
		withIntermediateDirectories: true
	)
	try VuplexCompatibility.launcherShimMarker.write(to: helper)
	let original = helper.deletingLastPathComponent().appending(
		path: VuplexCompatibility.originalHelperName)
	let officialData = Data("official-vx-accelerated-paint-disabled".utf8)
	try officialData.write(to: original)
	let userenv = helper.deletingLastPathComponent().appending(
		path: VuplexCompatibility.userenvName)
	try Data("Arknights Client AppContainer compatibility".utf8).write(to: userenv)
	let fallback = helper.deletingLastPathComponent().appending(
		path: ".arknights-client-vuplex-software-rendering")
	try Data().write(to: fallback)
	let compatibility = VuplexCompatibility(shimURL: nil, userenvURL: nil)

	#expect(try compatibility.restoreIfInstalled(in: root))
	#expect(try Data(contentsOf: helper) == officialData)
	#expect(!FileManager.default.fileExists(atPath: original.path))
	#expect(!FileManager.default.fileExists(atPath: userenv.path))
	#expect(!FileManager.default.fileExists(atPath: fallback.path))
}

@Test
func vuplexReconciliationRemovesAbandonedTemporaryFiles() throws {
	let root = FileManager.default.temporaryDirectory.appending(
		path: UUID().uuidString,
		directoryHint: .isDirectory
	)
	defer { try? FileManager.default.removeItem(at: root) }
	let helper = root.appending(path: VuplexCompatibility.helperRelativePath)
	let directory = helper.deletingLastPathComponent()
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	let temporaryFiles = [
		".arknights-client-vuplex-shim-old",
		".arknights-client-vuplex-previous-old",
		".arknights-client-userenv-old",
	]
	for name in temporaryFiles {
		try Data("temporary".utf8).write(to: directory.appending(path: name))
	}

	_ = try VuplexCompatibility(shimURL: nil, userenvURL: nil).restoreIfInstalled(in: root)

	for name in temporaryFiles {
		#expect(!FileManager.default.fileExists(atPath: directory.appending(path: name).path))
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

private func testCompatibility(shimURL: URL, root: URL) throws -> VuplexCompatibility {
	let userenvURL = root.appending(path: "bundled-userenv.dll")
	try Data("Arknights Client AppContainer compatibility".utf8).write(to: userenvURL)
	return VuplexCompatibility(shimURL: shimURL, userenvURL: userenvURL)
}
