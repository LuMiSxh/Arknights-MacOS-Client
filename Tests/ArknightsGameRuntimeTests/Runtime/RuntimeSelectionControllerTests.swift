// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsRuntimeTestSupport
import ArknightsTestSupport
import Foundation
import Synchronization
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
	AppPaths(
		applicationSupportDirectory: temporary.url,
		runtimeSelection: RuntimeSelection(override: .x86),
		runtimeAccess: access(macOS: 27)
	)
}

private func makeInstallOperation(paths: AppPaths) -> RuntimeSelectionController.InstallOperation {
	{ pin, _ in
		let directory = paths.runtimeVersionDirectory(for: pin.lane, version: pin.version)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		try Data(#"{"architecture":"\#(pin.lane.rawValue)"}"#.utf8).write(
			to: directory.appending(path: "RUNTIME.json"))
		return InstalledRuntime(lane: pin.lane, version: pin.version, directory: directory)
	}
}

/// A `select` refusal: the lane holds no runtime, or it holds one that is not the pinned version.
private struct SelectLaneCase: CustomTestStringConvertible, Sendable {
	let installedVersion: String?
	let state: RuntimeLaneState

	var testDescription: String {
		installedVersion.map { "installed \($0)" } ?? "not installed"
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
		selectionStore: RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile),
		lifecycle: makeLifecycleStore(in: storage),
		access: access,
		configuration: configuration,
		installOperation: installOperation
	)
}

@MainActor
struct RuntimeSelectionControllerTests {
	@Test
	func removalIsRefusedWhileAnotherActivityHoldsTheLeaseAndEndsItsOwnLease() async throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionRemoveTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		try makeInstalledRuntime(version: "1.0.0", lane: .x86, paths: paths)
		let controller = makeController(
			paths: paths,
			storage: temporary,
			configuration: try configuration(),
			access: access(macOS: 26),
			installOperation: makeInstallOperation(paths: paths)
		)
		let held = try #require(controller.lifecycle.begin(.maintaining(.clearingCache)))

		await #expect(throws: RuntimeSelectionError.busy) {
			try await controller.removeSelectedLane()
		}
		#expect(controller.installedVersion(for: .x86) == "1.0.0")
		controller.lifecycle.end(held)

		try await controller.removeSelectedLane()

		#expect(controller.installedVersion(for: .x86) == nil)
		#expect(controller.lifecycle.activity == .idle)
	}

	@Test
	func pausingBeforeTheFirstByteDoesNotReportAPausedDownload() async throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionEarlyPauseTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		let started = Mutex(false)
		let operation: RuntimeSelectionController.InstallOperation = { _, _ in
			started.withLock { $0 = true }
			let parked = AsyncStream<Void>(bufferingPolicy: .bufferingNewest(1)) { _ in }
			for await _ in parked {}
			throw CancellationError()
		}
		let controller = makeController(
			paths: paths,
			storage: temporary,
			configuration: try configuration(),
			access: access(macOS: 26),
			installOperation: operation
		)

		let install = Task { await controller.install(lane: .x86) }
		while !started.withLock({ $0 }) { await Task.yield() }
		controller.pauseInstall()

		#expect(await install.value == false)
		#expect(controller.pausedLane == nil)
		#expect(controller.failure == nil)
		#expect(controller.state(for: .x86) == .notInstalled)
	}

	@Test
	func pausedDownloadKeepsItsPartialFileIsNotAFailureAndResumes() async throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionPauseTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		let partURL = RuntimeInstaller.partialArchiveURL(
			for: try configuration().pinnedRuntime(for: .x86), paths: paths)
		let finish = makeInstallOperation(paths: paths)
		let calls = Mutex(0)
		let writing = Mutex(false)
		// The first call writes a partial archive and waits to be cancelled. The second completes.
		let operation: RuntimeSelectionController.InstallOperation = { pin, progress in
			let call = calls.withLock { value in
				value += 1
				return value
			}
			guard call == 1 else { return try await finish(pin, progress) }
			try FileManager.default.createDirectory(
				at: partURL.deletingLastPathComponent(), withIntermediateDirectories: true)
			try Data("partial".utf8).write(to: partURL)
			writing.withLock { $0 = true }
			// Suspends until Pause cancels the task; the stream never yields or finishes on its own.
			let parked = AsyncStream<Void>(bufferingPolicy: .bufferingNewest(1)) { _ in }
			for await _ in parked {}
			throw CancellationError()
		}
		let controller = makeController(
			paths: paths,
			storage: temporary,
			configuration: try configuration(),
			access: access(macOS: 26),
			installOperation: operation
		)

		let first = Task { await controller.install(lane: .x86) }
		while !writing.withLock({ $0 }) { await Task.yield() }
		controller.pauseInstall()

		#expect(await first.value == false)
		#expect(controller.pausedLane == .x86)
		#expect(controller.failure == nil)
		#expect(!controller.isInstalling)
		#expect(controller.lifecycle.activity == .idle)
		#expect(FileManager.default.fileExists(atPath: partURL.path))

		#expect(await controller.install(lane: .x86))
		#expect(controller.pausedLane == nil)
		#expect(controller.isSelectedLaneInstalled)
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
			access: access(macOS: 27),
			installOperation: makeInstallOperation(paths: paths)
		)

		#expect(await controller.install(lane: .arm) == false)
		#expect(controller.failure?.code == .runtimeNotInstalled)
	}

	@Test(arguments: [
		SelectLaneCase(installedVersion: nil, state: .notInstalled),
		SelectLaneCase(installedVersion: "0.8.0", state: .outdated(installed: "0.8.0")),
	])
	private func selectingALaneThatIsNotCurrentKeepsItSelected(_ testCase: SelectLaneCase) throws {
		let temporary = try TemporaryDirectory("RuntimeSelectionTests")
		defer { temporary.remove() }
		let paths = makePaths(temporary)
		if let version = testCase.installedVersion {
			try makeInstalledRuntime(version: version, lane: .arm, paths: paths)
		}
		let controller = makeController(
			paths: paths,
			storage: temporary,
			configuration: try configuration(),
			access: access(macOS: 27),
			installOperation: makeInstallOperation(paths: paths)
		)

		#expect(controller.state(for: .arm) == testCase.state)

		try controller.select(override: .arm)

		#expect(controller.selectedLane == .arm)
		#expect(controller.laneOverride == .arm)
	}
}
