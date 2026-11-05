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
			runtimeLane: lane
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
}
