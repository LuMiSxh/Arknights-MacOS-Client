// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsRuntimeTestSupport
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

/// A controller whose x86_64 runtime is installed and whose ARM64 download waits for `release`.
@MainActor
private struct SwitchFixture {
	let temporary: TemporaryDirectory
	let paths: AppPaths
	let controller: RuntimeSelectionController
	let release: AsyncStream<Void>.Continuation
	let access = RuntimeAccess(
		macOSVersion: OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))

	init(failingDownload: Bool = false) throws {
		temporary = try TemporaryDirectory("RuntimeSelectionSwitchTests")
		let paths = AppPaths(
			applicationSupportDirectory: temporary.url,
			runtimeSelection: RuntimeSelection(override: .x86),
			runtimeAccess: access
		)
		self.paths = paths
		try makeInstalledRuntime(version: "1.0.0", lane: .x86, paths: paths)
		let (gate, release) = AsyncStream<Void>.makeStream()
		self.release = release
		controller = RuntimeSelectionController(
			paths: paths,
			selectionStore: RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile),
			lifecycle: makeLifecycleStore(in: temporary),
			access: access,
			configuration: try makeRuntimeConfiguration(
				arm: makeRuntimeLane(
					version: "0.9.0+arm",
					minimumMacOS: "26.0",
					interface: makeRuntimeInterface(macDriver: "lib/wine/aarch64-unix/winemac.so"))),
			installOperation: { pin, _ in
				// A cancelled wait ends early, like an installer that finishes before it sees the cancel.
				for await _ in gate { break }
				if failingDownload { throw RuntimeInstallError.hashMismatch }
				let directory = paths.runtimeVersionDirectory(for: pin.lane, version: pin.version)
				try FileManager.default.createDirectory(
					at: directory, withIntermediateDirectories: true)
				try Data(#"{"architecture":"\#(pin.lane.rawValue)"}"#.utf8).write(
					to: directory.appending(path: "RUNTIME.json"))
				return InstalledRuntime(lane: pin.lane, version: pin.version, directory: directory)
			}
		)
	}

	var persistedLane: RuntimeLane {
		get throws {
			try RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile).load()
				.effectiveLane(access: access)
		}
	}

	/// Starts the ARM64 download and returns once it is running.
	func startARMDownload() async -> Task<Bool, Never> {
		let task = Task { await controller.install(lane: .arm) }
		while controller.installingLane == nil { await Task.yield() }
		return task
	}
}

@MainActor
struct RuntimeSelectionSwitchTests {
	@Test
	func switchingToAnUninstalledLaneSelectsItAtOnceSoHomeCannotPlay() async throws {
		let fixture = try SwitchFixture()
		defer { fixture.temporary.remove() }
		#expect(fixture.controller.isSelectedLaneInstalled)

		let download = await fixture.startARMDownload()

		#expect(fixture.controller.selectedLane == .arm)
		#expect(fixture.controller.selectedLaneState == .notInstalled)
		#expect(!fixture.controller.isSelectedLaneInstalled)
		#expect(try fixture.persistedLane == .arm)

		fixture.release.yield()
		#expect(await download.value)
		#expect(fixture.controller.selectedLane == .arm)
		#expect(fixture.controller.isSelectedLaneInstalled)
		#expect(fixture.controller.installedVersion(for: .arm) == "0.9.0+arm")
	}

	@Test
	func aFailedDownloadLeavesTheNewLaneSelectedAndNotInstalled() async throws {
		let fixture = try SwitchFixture(failingDownload: true)
		defer { fixture.temporary.remove() }
		let download = await fixture.startARMDownload()

		fixture.release.yield()

		#expect(await download.value == false)
		#expect(fixture.controller.selectedLane == .arm)
		#expect(!fixture.controller.isSelectedLaneInstalled)
		#expect(fixture.controller.failure?.code == .runtimeVerificationFailed)
		#expect(try fixture.persistedLane == .arm)
	}

	@Test
	func switchingBackDuringTheDownloadDiscardsItsLateCompletion() async throws {
		let fixture = try SwitchFixture()
		defer { fixture.temporary.remove() }
		let download = await fixture.startARMDownload()

		try fixture.controller.select(override: .x86)
		fixture.release.yield()

		#expect(await download.value == false)
		#expect(fixture.controller.selectedLane == .x86)
		#expect(try fixture.persistedLane == .x86)
		#expect(fixture.controller.failure == nil)
		#expect(fixture.controller.pausedLane == nil)
	}

	@Test
	func aLaunchInProgressRefusesToStartASwitch() throws {
		let fixture = try SwitchFixture()
		defer { fixture.temporary.remove() }
		fixture.controller.isLaunchInProgress = { true }

		#expect(throws: RuntimeSelectionError.busy) {
			try fixture.controller.selectForDownload(lane: .arm)
		}
		#expect(fixture.controller.selectedLane == .x86)
		#expect(try fixture.persistedLane == .x86)
	}
}
