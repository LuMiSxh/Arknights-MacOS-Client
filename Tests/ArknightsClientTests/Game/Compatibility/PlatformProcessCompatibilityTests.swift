// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func platformProcessNoticeWrapperUsesOneTimeCenteringCoarsePollingAndModalLock() throws {
	let repositoryRoot = (0..<5).reduce(URL(filePath: #filePath)) { url, _ in
		url.deletingLastPathComponent()
	}
	let sourceURL = repositoryRoot.appending(
		path: "RuntimeSupport/PlatformProcess/PlatformProcessShim.c"
	)
	let source = try String(contentsOf: sourceURL, encoding: .utf8)

	#expect(source.contains("center_notice_window"))
	#expect(source.contains("GetClientRect(game"))
	#expect(source.contains("ClientToScreen(game"))
	#expect(source.contains("NOTICE_DISCOVERY_INTERVAL_MS = 50"))
	#expect(source.contains("NOTICE_LIFECYCLE_INTERVAL_MS = 250"))
	#expect(!source.contains("follow_game_window"))
	#expect(!source.contains("wait_timeout = 8"))
	#expect(source.contains("disable_game_window"))
	#expect(source.contains("reassert_game_window"))
	#expect(source.contains("EnableWindow(game, FALSE)"))
	#expect(source.contains("EnableWindow(game, TRUE)"))
	#expect(source.contains("IsWindowEnabled(game)"))
	#expect(source.contains("if (!was_enabled || !game_identity_matches"))
	#expect(!source.contains("else if (IsWindowEnabled(game))"))
	#expect(source.contains("game_process_id"))
	#expect(source.contains("game_thread_id"))
	#expect(source.contains("GetWindowThreadProcessId(game"))
	func branchContains(_ branch: String, _ token: String) -> Bool {
		guard let start = source.range(of: branch) else { return false }
		let body = source[start.upperBound...]
		let end = body.range(of: "\n\t\tif (")?.lowerBound ?? body.endIndex
		return body[..<end].contains(token)
	}
	#expect(branchContains("if (discovered_notice != notice) {", "restore_game_window"))
	#expect(branchContains("if (discovered_game != game) {", "restore_game_window"))
	#expect(source.contains("if (wait == WAIT_OBJECT_0) break;"))
	#expect(source.contains("if (wait == WAIT_FAILED) {"))
	#expect(source.contains("exit_code = GetLastError();"))
	#expect(!source.contains("if (wait == WAIT_OBJECT_0 || wait == WAIT_FAILED) goto cleanup;"))
	#expect(source.contains("cleanup:\n\tif (has_locked_game)\n\t\trestore_game_window"))
	#expect(source.contains("} else if (!reassert_game_window("))

	let bridgeURL = repositoryRoot.appending(
		path: "RuntimeSupport/PlatformProcess/PlatformProcessWindowBridge.m"
	)
	let bridge = try String(contentsOf: bridgeURL, encoding: .utf8)
	#expect(bridge.contains("NSApplicationActivationPolicyAccessory"))
	#expect(bridge.contains("NSWindowCollectionBehaviorFullScreenAuxiliary"))
	#expect(bridge.contains("CGShieldingWindowLevel() + 1"))
	#expect(bridge.contains("NSColor.clearColor"))
	#expect(bridge.contains("CGPathCreateWithRoundedRect"))
	#expect(bridge.contains("acceptsFirstMouse"))
	#expect(bridge.contains("ignoresMouseEvents = NO"))
}

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
