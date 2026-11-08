// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

private func publishedARM() -> [String: Any] {
	makeRuntimeLane(
		version: "0.9.0+arm",
		minimumMacOS: "26.0",
		interface: makeRuntimeInterface(macDriver: "lib/wine/aarch64-unix/winemac.so"))
}

private func configuration(arm: [String: Any]? = nil) throws -> RuntimeConfiguration {
	try makeRuntimeConfiguration(arm: arm ?? publishedARM())
}

private func unpublishedARM() -> [String: Any] {
	makeRuntimeLane(
		version: "0.9.0+arm",
		url: "",
		sha256: "",
		sizeBytes: 0,
		minimumMacOS: "26.0",
		interface: makeRuntimeInterface(macDriver: "lib/wine/aarch64-unix/winemac.so")
	)
}

private func access(macOS major: Int) -> RuntimeAccess {
	RuntimeAccess(
		macOSVersion: OperatingSystemVersion(majorVersion: major, minorVersion: 0, patchVersion: 0))
}

private func makePaths(_ temporary: TemporaryDirectory) -> AppPaths {
	AppPaths(applicationSupportDirectory: temporary.url)
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
	storage: TemporaryDirectory,
	configuration: RuntimeConfiguration,
	access: RuntimeAccess,
	installOperation: @escaping RuntimeSelectionController.InstallOperation
) -> RuntimeSelectionController {
	RuntimeSelectionController(
		paths: paths,
		lifecycle: makeLifecycleStore(in: storage),
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
			storage: temporary,
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
			storage: temporary,
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
			storage: temporary,
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
			storage: temporary,
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
			storage: temporary,
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
			storage: temporary,
			configuration: try configuration(arm: unpublishedARM()),
			access: access(macOS: 26),
			installOperation: makeInstallOperation(paths: paths)
		)

		#expect(await controller.install(lane: .arm) == false)
		#expect(controller.failure?.code == .runtimeNotInstalled)
	}

	@Test
	func selectingAnUninstalledLaneIsRefused() throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		let controller = makeController(
			paths: paths,
			storage: temporary,
			configuration: try configuration(),
			access: access(macOS: 26),
			installOperation: makeInstallOperation(paths: paths)
		)

		#expect(throws: RuntimeSelectionError.notInstalled(.arm)) {
			try controller.select(lane: .arm)
		}
	}
}
