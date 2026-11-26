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
	func anOverrideIsPersistedForTheNextLaunch() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreSelectionTests")
		defer { temporary.remove() }
		let access = RuntimeAccess(
			macOSVersion: OperatingSystemVersion(
				majorVersion: 27, minorVersion: 0, patchVersion: 0))
		let paths = AppPaths(
			applicationSupportDirectory: temporary.url, runtimeAccess: access)
		let store = makeRuntimeStore(paths)

		try store.select(override: .x86, access: access)

		let reloaded = AppPaths(applicationSupportDirectory: temporary.url, runtimeAccess: access)
		#expect(reloaded.runtimeLane == .x86)
	}

	@Test
	func anARMOverrideIsRefusedBeforeItsMinimumMacOS() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreLaneGateTests")
		defer { temporary.remove() }
		let access = RuntimeAccess(
			macOSVersion: OperatingSystemVersion(
				majorVersion: 26, minorVersion: 4, patchVersion: 0))
		let paths = AppPaths(
			applicationSupportDirectory: temporary.url, runtimeAccess: access)
		let store = makeRuntimeStore(paths)

		#expect(throws: RuntimeStoreError.laneNotAllowed(.arm)) {
			try store.select(override: .arm, access: access)
		}
		let selection = try RuntimeSelectionStore(
			fileURL: paths.runtimeSelectionFile
		).load()
		#expect(selection.override == nil)
	}

	@Test
	func cleanupAndRemovalLeaveNoStaleVersionOrRecord() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreCleanupTests")
		defer { temporary.remove() }
		let paths = AppPaths(
			applicationSupportDirectory: temporary.url,
			runtimeSelection: RuntimeSelection(override: .x86)
		)
		let store = makeRuntimeStore(paths)
		try makeInstalledRuntime(version: "0.9.0", lane: .x86, paths: paths)
		try makeInstalledRuntime(version: "1.0.0", lane: .x86, paths: paths)
		try makeInstalledRuntime(version: "2.0.0", lane: .arm, paths: paths)
		let selectionStore = RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile)
		func exists(_ lane: RuntimeLane, _ version: String) -> Bool {
			FileManager.default.fileExists(
				atPath: paths.runtimeVersionDirectory(for: lane, version: version).path)
		}

		try store.cleanup(pinned: [.x86: "1.0.0"])

		// The stale version of the pinned lane goes, and the unpinned lane keeps its install.
		#expect(!exists(.x86, "0.9.0"))
		#expect(exists(.x86, "1.0.0"))
		#expect(exists(.arm, "2.0.0"))
		#expect(try selectionStore.load().installedVersions == [.x86: "1.0.0", .arm: "2.0.0"])

		try store.remove(lane: .arm)

		#expect(!exists(.arm, "2.0.0"))
		#expect(try selectionStore.load().installedVersions == [.x86: "1.0.0"])

		try store.cleanup(pinned: [.x86: "3.0.0"])

		#expect(!exists(.x86, "1.0.0"))
		#expect(try selectionStore.load().installedVersions.isEmpty)
	}

	@Test
	func removingTheSelectedLaneIsRefused() throws {
		let temporary = try TemporaryDirectory("RuntimeStoreRemoveTests")
		defer { temporary.remove() }
		let paths = AppPaths(
			applicationSupportDirectory: temporary.url,
			runtimeSelection: RuntimeSelection(override: .x86)
		)
		let store = makeRuntimeStore(paths)
		try makeInstalledRuntime(version: "1.0.0", lane: .x86, paths: paths)

		try RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile).save(
			RuntimeSelection(override: .x86))

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
				group.addTask { try store.select(override: .x86) }
				try await group.waitForAll()
			}
			let selection = try RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile).load()
			#expect(selection.installedVersions == [.x86: "1.0.0", .arm: "2.0.0"])
			#expect(selection.override == .x86)
		}
	}
}
