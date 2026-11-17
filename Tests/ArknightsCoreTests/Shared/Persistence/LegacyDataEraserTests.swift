// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

@Test
func erasingLegacyDataKeepsSymlinkTargetsAndWritesTheNewLayout() throws {
	let temporary = try TemporaryDirectory("LegacyDataEraserTests")
	defer { temporary.remove() }
	let root = temporary.url
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(
			path: "Support", directoryHint: .isDirectory),
		cachesDirectory: root.appending(path: "Caches", directoryHint: .isDirectory),
		libraryDirectory: root.appending(path: "Library", directoryHint: .isDirectory)
	)
	let fileManager = FileManager.default
	let support = paths.applicationSupportRoot
	let cache = paths.cacheRoot
	try fileManager.createDirectory(at: support, withIntermediateDirectories: true)
	try Data("old".utf8).write(to: support.appending(path: "old-data.json"))
	try fileManager.createDirectory(at: cache, withIntermediateDirectories: true)
	try Data("cache".utf8).write(to: cache.appending(path: "old-cache.json"))

	let outside = root.appending(path: "Outside", directoryHint: .isDirectory)
	try fileManager.createDirectory(at: outside, withIntermediateDirectories: true)
	let outsideMarker = outside.appending(path: "keep.txt")
	try Data("keep".utf8).write(to: outsideMarker)
	try fileManager.createSymbolicLink(
		at: support.appending(path: "outside-link"), withDestinationURL: outside)

	let suite = "LegacyDataEraserTests.\(UUID().uuidString)"
	let defaults = try #require(UserDefaults(suiteName: suite))
	defer { defaults.removePersistentDomain(forName: suite) }
	defaults.set(
		"/Old/Game", forKey: LauncherPreferencesStore.Key.installPath(for: .global))

	try LegacyDataEraser.erase(paths: paths)
	LegacyDataEraser.removeInstallPathKeys(userDefaults: defaults)

	#expect(fileManager.fileExists(atPath: support.path))
	#expect(try fileManager.contentsOfDirectory(atPath: support.path).isEmpty)
	#expect(fileManager.fileExists(atPath: cache.path))
	#expect(try fileManager.contentsOfDirectory(atPath: cache.path).isEmpty)
	#expect(fileManager.fileExists(atPath: outsideMarker.path))
	#expect(
		defaults.object(forKey: LauncherPreferencesStore.Key.installPath(for: .global)) == nil)

	try LayoutMigrator.writeFreshLayout(paths: paths)
	let document =
		try JSONSerialization.jsonObject(
			with: Data(contentsOf: paths.layoutFile)) as? [String: Int]
	#expect(document?["schemaVersion"] == AppConstants.Storage.layoutSchemaVersion)
}
