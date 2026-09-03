// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
@MainActor
func storageResolverUsesEveryRegionAndPersistedInstallLocation() throws {
	let root = temporaryStorageRoot()
	defer { try? FileManager.default.removeItem(at: root) }
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support"),
		cachesDirectory: root.appending(path: "Caches"),
		libraryDirectory: root.appending(path: "Library"),
		resourceDirectory: root.appending(path: "Resources")
	)
	let suiteName = "StorageOverviewTests.\(UUID().uuidString)"
	let defaults = UserDefaults(suiteName: suiteName)!
	defer { defaults.removePersistentDomain(forName: suiteName) }
	let preferences = LauncherPreferencesStore(defaults: defaults)
	let customJapan = root.appending(path: "External/Arknights-Japan")
	preferences.setInstallDirectory(customJapan, for: .japan)
	let browserCache = paths.winePrefix.appending(
		path: "drive_c/users/crossover/AppData/Local/cache", directoryHint: .isDirectory)
	try FileManager.default.createDirectory(at: browserCache, withIntermediateDirectories: true)

	let locations = StorageOverviewResolver.locations(paths: paths, preferences: preferences)

	#expect(locations.count == 9)
	#expect(
		locations.first { $0.category == .game(.japan) }?.urls.first?.path == customJapan.path
	)
	#expect(
		locations.first { $0.category == .game(.global) }?.urls.first?.path
			== paths.gameInstall(for: .global).path
	)
	#expect(
		locations.first { $0.category == .compatibilityRuntime }?.urls.first?.path
			== root.appending(path: "Resources/Runtime").path
	)
	#expect(
		locations.first { $0.category == .browserCache }?.urls.first?.resolvingSymlinksInPath()
			.path == browserCache.resolvingSymlinksInPath().path
	)
}

@Test
func storageSizeCalculatorAggregatesExistingPathsAndIgnoresSymlinks() throws {
	let fileManager = FileManager.default
	let root = temporaryStorageRoot()
	defer { try? fileManager.removeItem(at: root) }
	let first = root.appending(path: "first", directoryHint: .isDirectory)
	let second = root.appending(path: "second", directoryHint: .isDirectory)
	let outside = root.appending(path: "outside.bin")
	let outsideDirectory = root.appending(path: "outside-directory", directoryHint: .isDirectory)
	try fileManager.createDirectory(at: first, withIntermediateDirectories: true)
	try fileManager.createDirectory(at: second, withIntermediateDirectories: true)
	try Data(repeating: 0, count: 4).write(to: first.appending(path: "one"))
	try Data(repeating: 0, count: 6).write(to: second.appending(path: "two"))
	try Data(repeating: 0, count: 100).write(to: outside)
	try fileManager.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
	try Data(repeating: 0, count: 100).write(to: outsideDirectory.appending(path: "secret"))
	try fileManager.createSymbolicLink(
		at: first.appending(path: "outside"), withDestinationURL: outside)
	try fileManager.createSymbolicLink(
		at: first.appending(path: "outside-directory"), withDestinationURL: outsideDirectory)

	let measured = try StorageSizeCalculator.measure(
		[
			StorageLocation(category: .winePrefix, urls: [first, second]),
			StorageLocation(category: .logs, urls: [root.appending(path: "missing")]),
			StorageLocation(category: .compatibilityRuntime, urls: []),
		], fileManager: fileManager)

	#expect(measured[0].byteCount == 10)
	#expect(measured[0].exists)
	#expect(measured[1].byteCount == nil)
	#expect(!measured[1].exists)
	#expect(measured[2].byteCount == nil)
}

@Test
@MainActor
func galleryCleanupDoesNotOverlapActiveLifecycle() throws {
	let root = temporaryStorageRoot()
	defer { try? FileManager.default.removeItem(at: root) }
	let log = LauncherLog(fileURL: root.appending(path: "launcher.log"))
	let lifecycle = LauncherLifecycleStore(log: log)
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support"),
		cachesDirectory: root.appending(path: "Caches"),
		libraryDirectory: root.appending(path: "Library"),
		resourceDirectory: root.appending(path: "Resources")
	)
	let catalog = PresetCatalogService(cacheDirectory: paths.presetGalleryCache, log: log)
	let storage = StorageMaintenanceController(
		lifecycle: lifecycle,
		paths: paths,
		presetCatalog: catalog,
		log: log
	)
	lifecycle.activity = .installing(id: UUID(), stage: .downloading)

	storage.clearPresetGalleryCache()

	#expect(lifecycle.activity.isInstalling)
}

private func temporaryStorageRoot() -> URL {
	FileManager.default.temporaryDirectory.appending(
		path: "StorageOverviewTests.\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
}
