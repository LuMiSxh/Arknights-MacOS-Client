// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

private func makeInterface(macDriver: String) -> [String: Any] {
	[
		"archive": ["wineDirectory": "Wine", "dxmtDirectory": "DXMT"],
		"executables": ["bin/wine64", "bin/wineserver"],
		"features": [
			"hardwareCursor": true,
			"metalFXSpatialUpscaling": true,
			"nativeFullscreenSpace": true,
		],
		"requiredFiles": ["lib/wine/x86_64-unix/winemac.so"],
		"macDriver": macDriver,
		"launcher": ["path": "bin/Arknights", "target": "wine64"],
		"dxmt": [
			"payloadDirectory": "DXMT",
			"destinations": ["x64": "system32"],
			"libraries": ["d3d11.dll"],
		],
	]
}

private func lane(
	version: String = "1.0.0",
	url: String = "https://example.test/runtime.tar.gz",
	sha256: String = String(repeating: "a", count: 64),
	sizeBytes: Int = 4,
	minimumMacOS: String = "15.0",
	macDriver: String = "lib/wine/x86_64-unix/winemac.so"
) -> [String: Any] {
	[
		"minimumMacOS": minimumMacOS,
		"prefixRevision": 2,
		"runtime": [
			"name": "Test Runtime",
			"version": version,
			"url": url,
			"sha256": sha256,
			"sizeBytes": sizeBytes,
		],
		"interface": makeInterface(macDriver: macDriver),
		"components": ["wine": "11.17", "dxmt": "0.80"],
		"provenance": ["wineCommit": "e0aa380780b73e20fabcfe78fd42713b94929a53"],
	]
}

private func configuration(arm: [String: Any]? = nil) throws -> RuntimeConfiguration {
	let lanes: [String: Any] = [
		"x86": lane(),
		"arm": arm
			?? lane(
				version: "0.9.0+arm",
				minimumMacOS: "26.0",
				macDriver: "lib/wine/aarch64-unix/winemac.so"
			),
	]
	let root: [String: Any] = [
		"schemaVersion": 3,
		"architecture": "x86",
		"prefixRevision": 2,
		"lanes": lanes,
	]
	return try JSONDecoder().decode(
		RuntimeConfiguration.self, from: JSONSerialization.data(withJSONObject: root))
}

private func unpublishedARM() -> [String: Any] {
	lane(
		version: "0.9.0+arm",
		url: "",
		sha256: "",
		sizeBytes: 0,
		minimumMacOS: "26.0",
		macDriver: "lib/wine/aarch64-unix/winemac.so"
	)
}

private func access(macOS major: Int) -> RuntimeAccess {
	RuntimeAccess(
		macOSVersion: OperatingSystemVersion(majorVersion: major, minorVersion: 0, patchVersion: 0))
}

private func makePaths(_ temporary: TemporaryDirectory) -> AppPaths {
	AppPaths(applicationSupportDirectory: temporary.url)
}

private func makeInstalledRuntime(
	version: String,
	lane: RuntimeLane,
	paths: AppPaths
) throws {
	let directory = paths.runtimeVersionDirectory(for: lane, version: version)
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	try Data(#"{"architecture":"\#(lane.rawValue)"}"#.utf8).write(
		to: directory.appending(path: "RUNTIME.json"))
}

private func makeInstallOperation(
	paths: AppPaths,
	throwsVerificationError: Bool = false
) -> RuntimeSelectionController.InstallOperation {
	{ pin, _ in
		if throwsVerificationError { throw RuntimeInstallError.hashMismatch }
		let directory = paths.runtimeVersionDirectory(for: pin.lane, version: pin.version)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		try Data(#"{"architecture":"\#(pin.lane.rawValue)"}"#.utf8).write(
			to: directory.appending(path: "RUNTIME.json"))
		return InstalledRuntime(lane: pin.lane, version: pin.version, directory: directory)
	}
}

@MainActor
private func makeController(
	paths: AppPaths,
	configuration: RuntimeConfiguration,
	access: RuntimeAccess,
	installOperation: @escaping RuntimeSelectionController.InstallOperation
) -> RuntimeSelectionController {
	RuntimeSelectionController(
		paths: paths,
		lifecycle: makeLifecycleStore(),
		access: access,
		configuration: configuration,
		installOperation: installOperation
	)
}

@MainActor
struct RuntimeSelectionControllerTests {
	@Test
	func offersX86AndARMOnMacOS26() throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		let controller = makeController(
			paths: paths,
			configuration: try configuration(),
			access: access(macOS: 26),
			installOperation: makeInstallOperation(paths: paths)
		)

		#expect(controller.availableLanes == [.x86, .arm])
		#expect(controller.installedVersion(for: .x86) == nil)
		#expect(!controller.isSelectedLaneInstalled)
	}

	@Test
	func offersOnlyX86BeforeMacOS26() throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		let controller = makeController(
			paths: paths,
			configuration: try configuration(),
			access: access(macOS: 25),
			installOperation: makeInstallOperation(paths: paths)
		)

		#expect(controller.availableLanes == [.x86])
	}

	@Test
	func doesNotOfferAnUnpublishedARMPin() throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		let controller = makeController(
			paths: paths,
			configuration: try configuration(arm: unpublishedARM()),
			access: access(macOS: 26),
			installOperation: makeInstallOperation(paths: paths)
		)

		#expect(controller.availableLanes == [.x86])
		#expect(controller.pinnedRuntime(for: .arm)?.isAvailable == false)
	}

	@Test
	func installingALaneSelectsItAndRecordsTheVersion() async throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		let controller = makeController(
			paths: paths,
			configuration: try configuration(),
			access: access(macOS: 26),
			installOperation: makeInstallOperation(paths: paths)
		)

		#expect(await controller.install(lane: .arm))
		#expect(controller.selectedLane == .arm)
		#expect(controller.installedVersion(for: .arm) == "0.9.0+arm")
		#expect(controller.requiresRelaunch)
		let selection = try RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile).load()
		#expect(selection.selected == .arm)
	}

	@Test
	func aVerificationFailureExposesTheRuntimeVerificationCode() async throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		let controller = makeController(
			paths: paths,
			configuration: try configuration(),
			access: access(macOS: 26),
			installOperation: makeInstallOperation(
				paths: paths, throwsVerificationError: true)
		)

		#expect(await controller.install(lane: .arm) == false)
		#expect(controller.failure?.code == .runtimeVerificationFailed)
		#expect(controller.selectedLane == .x86)
		#expect(controller.installedVersion(for: .arm) == nil)
	}

	@Test
	func anUnpublishedLaneFailsWithTheNotInstalledCode() async throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		let controller = makeController(
			paths: paths,
			configuration: try configuration(arm: unpublishedARM()),
			access: access(macOS: 26),
			installOperation: makeInstallOperation(paths: paths)
		)

		#expect(await controller.install(lane: .arm) == false)
		#expect(controller.failure?.code == .runtimeNotInstalled)
	}

	@Test
	func selectingAnInstalledLaneIsPersisted() throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		try makeInstalledRuntime(version: "0.9.0+arm", lane: .arm, paths: paths)
		let controller = makeController(
			paths: paths,
			configuration: try configuration(),
			access: access(macOS: 26),
			installOperation: makeInstallOperation(paths: paths)
		)

		try controller.select(lane: .arm)

		#expect(controller.selectedLane == .arm)
		#expect(controller.requiresRelaunch)
		let reloaded = AppPaths(applicationSupportDirectory: temporary.url)
		#expect(reloaded.runtimeLane == .arm)
	}

	@Test
	func selectingAnUninstalledLaneIsRefused() throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		let controller = makeController(
			paths: paths,
			configuration: try configuration(),
			access: access(macOS: 26),
			installOperation: makeInstallOperation(paths: paths)
		)

		#expect(throws: RuntimeSelectionError.notInstalled(.arm)) {
			try controller.select(lane: .arm)
		}
	}

	@Test
	func removingTheOtherLaneKeepsTheSelectedLane() throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		try makeInstalledRuntime(version: "1.0.0", lane: .x86, paths: paths)
		try makeInstalledRuntime(version: "0.9.0+arm", lane: .arm, paths: paths)
		let controller = makeController(
			paths: paths,
			configuration: try configuration(),
			access: access(macOS: 26),
			installOperation: makeInstallOperation(paths: paths)
		)

		try controller.removeOtherLane()

		#expect(controller.installedVersion(for: .x86) == "1.0.0")
		#expect(controller.installedVersion(for: .arm) == nil)
	}

	@Test
	func removingTheOtherLaneNeverRemovesTheSelectedLane() throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		try makeInstalledRuntime(version: "1.0.0", lane: .x86, paths: paths)
		let controller = makeController(
			paths: paths,
			configuration: try configuration(),
			access: access(macOS: 26),
			installOperation: makeInstallOperation(paths: paths)
		)

		try controller.removeOtherLane()

		#expect(controller.installedVersion(for: .x86) == "1.0.0")
		#expect(
			FileManager.default.fileExists(
				atPath: paths.runtimeVersionDirectory(for: .x86, version: "1.0.0").path))
	}
}
