// SPDX-License-Identifier: MPL-2.0

import ArknightsRuntimeTestSupport
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore
@testable import ArknightsGameRuntime

private func makeRuntimeStore(_ paths: AppPaths) -> RuntimeStore {
	RuntimeStore(
		paths: paths, selectionStore: RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile))
}

struct RuntimeStoreTests {
	@Test
	func selectionIsPersistedAndDefaultsToARM() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreSelectionTests")
		defer { temporary.remove() }
		let access = RuntimeAccess(
			macOSVersion: OperatingSystemVersion(
				majorVersion: 26, minorVersion: 0, patchVersion: 0))
		let paths = AppPaths(
			applicationSupportDirectory: temporary.url, runtimeAccess: access)
		let store = makeRuntimeStore(paths)

		let initialSelection = try RuntimeSelectionStore(
			fileURL: paths.runtimeSelectionFile
		).load(access: access)
		#expect(initialSelection.selected == .arm)

		try store.select(lane: .x86, access: access)

		let reloaded = AppPaths(applicationSupportDirectory: temporary.url)
		#expect(reloaded.runtimeLane == .x86)
		#expect(reloaded.winePrefix(for: .yostar).lastPathComponent == "yostar-x86")
	}

	@Test
	func armSelectionIsRefusedBeforeMacOS26() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreLaneGateTests")
		defer { temporary.remove() }
		let access = RuntimeAccess(
			macOSVersion: OperatingSystemVersion(
				majorVersion: 25, minorVersion: 0, patchVersion: 0))
		let paths = AppPaths(
			applicationSupportDirectory: temporary.url, runtimeAccess: access)
		let store = makeRuntimeStore(paths)

		#expect(throws: RuntimeStoreError.laneNotAllowed(.arm)) {
			try store.select(lane: .arm, access: access)
		}
		let selection = try RuntimeSelectionStore(
			fileURL: paths.runtimeSelectionFile
		).load(access: access)
		#expect(selection.selected == .x86)
	}

	@Test
	func cleanupRemovesStaleVersionsOfPinnedLanesOnly() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreCleanupTests")
		defer { temporary.remove() }
		let paths = AppPaths(applicationSupportDirectory: temporary.url)
		let store = makeRuntimeStore(paths)
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
		let store = makeRuntimeStore(paths)
		try makeInstalledRuntime(version: "1.0.0", lane: .x86, paths: paths)

		try RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile).save(
			RuntimeSelection(selected: .x86))

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
	func aCorruptRuntimeDocumentIsRebuiltOnInstall() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreCorruptTests")
		defer { temporary.remove() }
		let paths = AppPaths(applicationSupportDirectory: temporary.url)
		try makeInstalledRuntime(version: "1.0.0", lane: .x86, paths: paths)
		try Data(#"{"selected":"x8"#.utf8).write(to: paths.runtimeSelectionFile)

		try makeRuntimeStore(paths).recordInstalled(lane: .arm, version: "2.0.0")

		let selection = try RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile).load()
		#expect(selection.installedVersions == [.x86: "1.0.0", .arm: "2.0.0"])
	}

	@Test
	func aMissingRuntimeDocumentIsRebuiltFromTheVersionDirectories() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreRebuildTests")
		defer { temporary.remove() }
		let paths = AppPaths(applicationSupportDirectory: temporary.url)
		try makeInstalledRuntime(version: "0.9.0", lane: .x86, paths: paths)
		try makeInstalledRuntime(version: "1.10.0", lane: .x86, paths: paths)
		try makeInstalledRuntime(version: "2.0.0", lane: .arm, paths: paths)
		// A directory without a valid manifest is not an install.
		try FileManager.default.createDirectory(
			at: paths.runtimeVersionDirectory(for: .arm, version: "9.0.0"),
			withIntermediateDirectories: true)
		try FileManager.default.removeItem(at: paths.runtimeSelectionFile)

		try makeRuntimeStore(paths).recoverRecordIfNeeded()

		let selection = try RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile).load()
		#expect(selection.installedVersions == [.x86: "1.10.0", .arm: "2.0.0"])
	}

	@Test
	func concurrentInstallRecordsKeepBothLanes() async throws {
		let temporary = try TemporaryDirectory("RuntimeStoreConcurrentTests")
		defer { temporary.remove() }
		for iteration in 0..<40 {
			let paths = AppPaths(
				applicationSupportDirectory: temporary.url.appending(path: "run-\(iteration)"))
			let store = makeRuntimeStore(paths)
			try await withThrowingTaskGroup(of: Void.self) { group in
				group.addTask { try store.recordInstalled(lane: .x86, version: "1.0.0") }
				group.addTask { try store.recordInstalled(lane: .arm, version: "2.0.0") }
				group.addTask { try store.select(lane: .x86) }
				try await group.waitForAll()
			}
			let selection = try RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile).load()
			#expect(selection.installedVersions == [.x86: "1.0.0", .arm: "2.0.0"])
			#expect(selection.selected == .x86)
		}
	}

	@Test
	func removeAndCleanupLeaveNoStaleRecord() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreStaleRecordTests")
		defer { temporary.remove() }
		let paths = AppPaths(
			applicationSupportDirectory: temporary.url,
			runtimeSelection: RuntimeSelection(selected: .x86))
		let store = makeRuntimeStore(paths)
		try makeInstalledRuntime(version: "1.0.0", lane: .x86, paths: paths)
		try makeInstalledRuntime(version: "2.0.0", lane: .arm, paths: paths)
		let selectionStore = RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile)

		try store.remove(lane: .arm)
		#expect(try selectionStore.load().installedVersions == [.x86: "1.0.0"])
		#expect(
			!FileManager.default.fileExists(
				atPath: paths.runtimeVersionDirectory(for: .arm, version: "2.0.0").path))

		try store.cleanup(pinned: [.x86: "3.0.0"])
		#expect(try selectionStore.load().installedVersions.isEmpty)
	}
}
