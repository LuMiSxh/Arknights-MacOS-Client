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
	#expect(paths.winePrefix(for: .taiwan) == paths.gryphlineWinePrefix)

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

	#expect(x86.winePrefix.lastPathComponent == "Prefix")
	#expect(arm.winePrefix.lastPathComponent == "Prefix-ARM64")
	#expect(x86.winePrefix != arm.winePrefix)
	#expect(x86.winePrefix(for: .china) != arm.winePrefix(for: .china))
	#expect(x86.winePrefix(for: .taiwan) != arm.winePrefix(for: .taiwan))
	#expect(x86.gameInstall(for: .global) == arm.gameInstall(for: .global))
	#expect(x86.winePrefix(for: .global, lane: .arm) == arm.winePrefix)
}

@Test
func runtimeStorePathsStayOutsideTheAppBundle() throws {
	let temporary = try TemporaryDirectory("AppPathsRuntimeTests")
	defer { temporary.remove() }
	let paths = AppPaths(applicationSupportDirectory: temporary.url)

	#expect(paths.runtimeRoot.lastPathComponent == "Runtimes")
	#expect(paths.runtimeDownloadsDirectory.lastPathComponent == ".downloads")
	#expect(paths.runtimeStagingRoot.lastPathComponent == ".staging")
	#expect(paths.runtimeSelectionFile.lastPathComponent == "runtime-selection.json")
	#expect(!paths.runtimeDirectory(for: .x86).path.contains(".app/"))
	#expect(!paths.runtimeDirectory(for: .arm).path.contains(".app/"))
}

@Test
func runtimeSelectionDeterminesTheLane() throws {
	let temporary = try TemporaryDirectory("AppPathsSelectionTests")
	defer { temporary.remove() }
	let support = temporary.url.appending(path: "Support", directoryHint: .isDirectory)
	let applicationSupport = support.appending(
		path: AppPaths.bundleIdentifier, directoryHint: .isDirectory)
	try FileManager.default.createDirectory(
		at: applicationSupport, withIntermediateDirectories: true)
	try Data(#"{"selected":"arm"}"#.utf8).write(
		to: applicationSupport.appending(path: "runtime-selection.json"))

	let paths = AppPaths(applicationSupportDirectory: support)

	#expect(paths.runtimeLane == .arm)
	#expect(paths.winePrefix.lastPathComponent == "Prefix-ARM64")
	#expect(paths.runtimeLaneDiagnostic == nil)
}

@Test
func missingSelectionDefaultsToX86WhateverTheRuntimeTreesHold() throws {
	let temporary = try TemporaryDirectory("AppPathsDefaultLaneTests")
	defer { temporary.remove() }
	let support = temporary.url.appending(path: "Support", directoryHint: .isDirectory)
	let applicationSupport = support.appending(
		path: AppPaths.bundleIdentifier, directoryHint: .isDirectory)
	let armRuntime = applicationSupport.appending(
		path: "Runtimes/arm/2.0.0", directoryHint: .isDirectory)
	try FileManager.default.createDirectory(at: armRuntime, withIntermediateDirectories: true)
	try Data(#"{"architecture":"arm"}"#.utf8).write(
		to: armRuntime.appending(path: "RUNTIME.json"))

	let paths = AppPaths(applicationSupportDirectory: support)

	#expect(paths.runtimeLane == .x86)
	#expect(paths.winePrefix.lastPathComponent == "Prefix")
}

@Test
func activeRuntimeConfigurationFollowsTheSelectedLane() throws {
	let temporary = try TemporaryDirectory("AppPathsActiveRuntimeTests")
	defer { temporary.remove() }
	let support = temporary.url.appending(path: "Support", directoryHint: .isDirectory)
	let applicationSupport = support.appending(
		path: AppPaths.bundleIdentifier, directoryHint: .isDirectory)
	for lane in ["x86", "arm"] {
		let version = applicationSupport.appending(
			path: "Runtimes/\(lane)/1.0.0", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: version, withIntermediateDirectories: true)
		try Data(#"{"architecture":"\#(lane)"}"#.utf8).write(
			to: version.appending(path: "RUNTIME.json"))
	}

	let x86 = AppPaths(
		applicationSupportDirectory: support,
		runtimeSelection: RuntimeSelection(selected: .x86)
	)
	let arm = AppPaths(
		applicationSupportDirectory: support,
		runtimeSelection: RuntimeSelection(selected: .arm)
	)

	#expect(x86.activeRuntimeConfigurationURL()?.path.hasSuffix("x86/1.0.0/RUNTIME.json") == true)
	#expect(arm.activeRuntimeConfigurationURL()?.path.hasSuffix("arm/1.0.0/RUNTIME.json") == true)
	let installed = AppPaths.installedRuntimeConfigurationURLs(in: x86.runtimeRoot)
	#expect(installed.map(\.lane) == [.x86, .arm])
}
