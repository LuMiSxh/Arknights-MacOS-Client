// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

private final class FailingCacheEnumerationFileManager: FileManager {
	override func contentsOfDirectory(
		at url: URL,
		includingPropertiesForKeys keys: [URLResourceKey]? = nil,
		options mask: FileManager.DirectoryEnumerationOptions = []
	) throws -> [URL] {
		throw CocoaError(.fileReadNoPermission)
	}
}

@Test
func winePrefixesFollowRegionOwnershipAndCacheEnumerationFailsLoudly() throws {
	let temporary = try TemporaryDirectory("AppPathsTests")
	defer { temporary.remove() }
	let root = temporary.url
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support"),
		cachesDirectory: root.appending(path: "Caches"),
		libraryDirectory: root.appending(path: "Library")
	)
	#expect(paths.winePrefix(for: .chinaBilibili) == paths.winePrefix(for: .china))
	#expect(paths.winePrefix(for: .taiwan) == paths.winePrefix(for: .gryphline))

	let missingPrefix = root.appending(path: "MissingCacheUsers", directoryHint: .isDirectory)
	#expect(try AppPaths.gameCacheDirectories(winePrefix: missingPrefix).isEmpty)
	#expect(throws: AppPathsError.self) {
		try AppPaths.gameCacheDirectories(
			winePrefix: root.appending(path: "Unreadable", directoryHint: .isDirectory),
			fileManager: FailingCacheEnumerationFileManager()
		)
	}
}

@Test
func runtimeLanesUseSeparateWinePrefixes() throws {
	let temporary = try TemporaryDirectory("AppPathsLaneTests")
	defer { temporary.remove() }
	let root = temporary.url
	func paths(_ lane: RuntimeLane) -> AppPaths {
		AppPaths(
			applicationSupportDirectory: root.appending(path: "Support"),
			cachesDirectory: root.appending(path: "Caches"),
			libraryDirectory: root.appending(path: "Library"),
			runtimeSelection: RuntimeSelection(selected: lane)
		)
	}
	let x86 = paths(.x86)
	let arm = paths(.arm)

	#expect(x86.winePrefix(for: .yostar).lastPathComponent == "yostar-x86")
	#expect(arm.winePrefix(for: .yostar).lastPathComponent == "yostar-arm")
	#expect(x86.winePrefix(for: .yostar) != arm.winePrefix(for: .yostar))
	#expect(x86.winePrefix(for: .china) != arm.winePrefix(for: .china))
	#expect(x86.winePrefix(for: .taiwan) != arm.winePrefix(for: .taiwan))
	#expect(x86.gameInstall(for: .global) == arm.gameInstall(for: .global))
	#expect(x86.winePrefix(for: .global, lane: .arm) == arm.winePrefix(for: .yostar))
}

@Test
func runtimeStorePathsStayOutsideTheAppBundle() throws {
	let temporary = try TemporaryDirectory("AppPathsRuntimeTests")
	defer { temporary.remove() }
	let paths = AppPaths(applicationSupportDirectory: temporary.url)

	#expect(paths.runtimeRoot.lastPathComponent == "Runtimes")
	#expect(paths.runtimeDownloadsDirectory.lastPathComponent == "Downloads")
	#expect(paths.runtimeStagingRoot.lastPathComponent == ".staging")
	#expect(paths.runtimeSelectionFile.lastPathComponent == "runtime-selection.json")
	#expect(
		paths.runtimeVersionDirectory(for: .x86, version: "1.0.0").lastPathComponent
			== "x86-1.0.0")
	#expect(!paths.runtimeVersionDirectory(for: .x86, version: "1.0.0").path.contains(".app/"))
	#expect(!paths.runtimeVersionDirectory(for: .arm, version: "1.0.0").path.contains(".app/"))
}

@Test
func missingSelectionDefaultsToARMWhateverTheRuntimeTreesHold() throws {
	let temporary = try TemporaryDirectory("AppPathsDefaultLaneTests")
	defer { temporary.remove() }
	let support = temporary.url.appending(path: "Support", directoryHint: .isDirectory)
	let applicationSupport = support.appending(
		path: AppPaths.bundleIdentifier, directoryHint: .isDirectory)
	let armRuntime = applicationSupport.appending(
		path: "Runtimes/arm-2.0.0", directoryHint: .isDirectory)
	try FileManager.default.createDirectory(at: armRuntime, withIntermediateDirectories: true)
	try Data(#"{"architecture":"arm"}"#.utf8).write(
		to: armRuntime.appending(path: "RUNTIME.json"))

	let paths = AppPaths(
		applicationSupportDirectory: support,
		runtimeAccess: RuntimeAccess(
			macOSVersion: OperatingSystemVersion(
				majorVersion: 26, minorVersion: 0, patchVersion: 0))
	)

	#expect(paths.runtimeLane == .arm)
	#expect(paths.winePrefix(for: .yostar).lastPathComponent == "yostar-arm")
	#expect(paths.installedRuntimeVersion(for: .arm) == nil)
}
