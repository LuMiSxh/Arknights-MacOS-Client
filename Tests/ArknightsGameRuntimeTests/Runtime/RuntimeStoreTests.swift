// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore
@testable import ArknightsGameRuntime

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

struct RuntimeStoreTests {
	@Test
	func findsTheInstalledVersionPerLane() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreTests")
		defer { temporary.remove() }
		let paths = AppPaths(applicationSupportDirectory: temporary.url)
		let store = RuntimeStore(paths: paths)
		try makeInstalledRuntime(version: "1.0.0", lane: .x86, paths: paths)

		#expect(store.installedVersion(for: .x86) == "1.0.0")
		#expect(store.installedVersion(for: .arm) == nil)
	}

	@Test
	func selectionIsPersistedAndDefaultsToX86() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreSelectionTests")
		defer { temporary.remove() }
		let paths = AppPaths(applicationSupportDirectory: temporary.url)
		let store = RuntimeStore(paths: paths)

		let initialSelection = try RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile).load()
		#expect(initialSelection.selected == .x86)

		let access = RuntimeAccess(
			macOSVersion: OperatingSystemVersion(
				majorVersion: 26, minorVersion: 0, patchVersion: 0))
		try store.select(lane: .arm, access: access)

		let reloaded = AppPaths(applicationSupportDirectory: temporary.url)
		#expect(reloaded.runtimeLane == .arm)
		#expect(reloaded.winePrefix.lastPathComponent == "Prefix-ARM64")
	}

	@Test
	func armSelectionIsRefusedBeforeMacOS26() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreLaneGateTests")
		defer { temporary.remove() }
		let paths = AppPaths(applicationSupportDirectory: temporary.url)
		let store = RuntimeStore(paths: paths)
		let access = RuntimeAccess(
			macOSVersion: OperatingSystemVersion(
				majorVersion: 25, minorVersion: 0, patchVersion: 0))

		#expect(throws: RuntimeStoreError.laneNotAllowed(.arm)) {
			try store.select(lane: .arm, access: access)
		}
		let selection = try RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile).load()
		#expect(selection.selected == .x86)
	}

	@Test
	func cleanupRemovesStaleVersionsOfPinnedLanesOnly() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreCleanupTests")
		defer { temporary.remove() }
		let paths = AppPaths(applicationSupportDirectory: temporary.url)
		let store = RuntimeStore(paths: paths)
		try makeInstalledRuntime(version: "0.9.0", lane: .x86, paths: paths)
		try makeInstalledRuntime(version: "1.0.0", lane: .x86, paths: paths)
		try makeInstalledRuntime(version: "2.0.0", lane: .arm, paths: paths)

		try store.cleanup(pinned: [.x86: "1.0.0"])

		#expect(
			!FileManager.default.fileExists(
				atPath: paths.runtimeVersionDirectory(
					for: .x86, version: "0.9.0"
				).path))
		#expect(
			FileManager.default.fileExists(
				atPath: paths.runtimeVersionDirectory(
					for: .x86, version: "1.0.0"
				).path))
		#expect(
			FileManager.default.fileExists(
				atPath: paths.runtimeVersionDirectory(
					for: .arm, version: "2.0.0"
				).path))
	}

	@Test
	func removingTheSelectedLaneIsRefused() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreRemoveTests")
		defer { temporary.remove() }
		let paths = AppPaths(
			applicationSupportDirectory: temporary.url,
			runtimeSelection: RuntimeSelection(selected: .x86)
		)
		let store = RuntimeStore(paths: paths)
		try makeInstalledRuntime(version: "1.0.0", lane: .x86, paths: paths)

		#expect(throws: RuntimeStoreError.cannotRemoveSelectedLane(.x86)) {
			try store.remove(lane: .x86)
		}
		#expect(
			FileManager.default.fileExists(
				atPath: paths.runtimeVersionDirectory(
					for: .x86, version: "1.0.0"
				).path))
	}

	@Test
	func removingAnotherLaneDeletesItsInstalledRuntime() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreRemoveOtherTests")
		defer { temporary.remove() }
		let paths = AppPaths(
			applicationSupportDirectory: temporary.url,
			runtimeSelection: RuntimeSelection(selected: .x86)
		)
		let store = RuntimeStore(paths: paths)
		try makeInstalledRuntime(version: "2.0.0", lane: .arm, paths: paths)

		try store.remove(lane: .arm)

		#expect(store.installedVersion(for: .arm) == nil)
		#expect(!FileManager.default.fileExists(atPath: paths.runtimeDirectory(for: .arm).path))
	}
}
