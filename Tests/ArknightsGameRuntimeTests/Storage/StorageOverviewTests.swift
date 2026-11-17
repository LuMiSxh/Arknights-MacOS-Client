// SPDX-License-Identifier: MPL-2.0

import ArknightsCustomization
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore
@testable import ArknightsGameRuntime

@Test
@MainActor
func storageResolverUsesEveryRegionAndPersistedInstallLocation() throws {
	let temporary = try TemporaryDirectory("StorageOverviewTests")
	defer { temporary.remove() }
	let root = temporary.url
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support"),
		cachesDirectory: root.appending(path: "Caches"),
		libraryDirectory: root.appending(path: "Library")
	)
	let (defaults, suiteName) = makeIsolatedDefaults("StorageOverviewTests")
	defer { defaults.removePersistentDomain(forName: suiteName) }
	let preferences = LauncherPreferencesStore(defaults: defaults)
	let customJapan = root.appending(path: "External/Arknights-Japan")
	preferences.setInstallDirectory(customJapan, for: .japan)
	let browserCache = paths.winePrefix(for: .yostar).appending(
		path: "drive_c/users/crossover/AppData/Local/cache", directoryHint: .isDirectory)
	try FileManager.default.createDirectory(at: browserCache, withIntermediateDirectories: true)

	let context = StorageOverviewResolver.context(preferences: preferences, region: .global)
	let locations = try StorageOverviewResolver.locations(paths: paths, context: context)

	#expect(locations.count == 12)
	#expect(
		locations.first { $0.category == .game(.japan) }?.urls.first?.path == customJapan.path
	)
	#expect(
		locations.first { $0.category == .game(.global) }?.urls.first?.path
			== paths.gameInstall(for: .global).path
	)
	#expect(
		locations.first { $0.category == .compatibilityRuntime }?.urls.first?.path
			== paths.runtimeRoot.path
	)
	#expect(
		locations.first { $0.category == .browserCache }?.urls.first?.resolvingSymlinksInPath()
			.path == browserCache.resolvingSymlinksInPath().path
	)
}

@Test
@MainActor
func galleryCleanupDoesNotOverlapActiveLifecycle() throws {
	let temporary = try TemporaryDirectory("StorageOverviewTests")
	defer { temporary.remove() }
	let root = temporary.url
	let log = LauncherLog(fileURL: root.appending(path: "launcher.log"))
	let lifecycle = LauncherLifecycleStore(log: log)
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support"),
		cachesDirectory: root.appending(path: "Caches"),
		libraryDirectory: root.appending(path: "Library")
	)
	let catalog = PresetCatalogService(cacheDirectory: paths.presetGalleryCache, log: log)
	let storage = StorageMaintenanceController(
		lifecycle: lifecycle,
		paths: paths,
		clearGalleryCache: { try await catalog.clearCaches() },
		log: log
	)
	let lease = lifecycle.begin(.installing(id: UUID(), stage: .downloading))
	#expect(lease != nil)

	storage.clearPresetGalleryCache()

	#expect(lifecycle.activity.isInstalling)
}
