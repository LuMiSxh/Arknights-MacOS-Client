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
		libraryDirectory: root.appending(path: "Library"),
		resourceDirectory: root.appending(path: "Resources")
	)
	let (defaults, suiteName) = makeIsolatedDefaults("StorageOverviewTests")
	defer { defaults.removePersistentDomain(forName: suiteName) }
	let preferences = LauncherPreferencesStore(defaults: defaults)
	let customJapan = root.appending(path: "External/Arknights-Japan")
	preferences.setInstallDirectory(customJapan, for: .japan)
	let browserCache = paths.winePrefix.appending(
		path: "drive_c/users/crossover/AppData/Local/cache", directoryHint: .isDirectory)
	try FileManager.default.createDirectory(at: browserCache, withIntermediateDirectories: true)

	let locations = try StorageOverviewResolver.locations(paths: paths, preferences: preferences)

	#expect(locations.count == 11)
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

	for canary in [true, false] {
		let filtered = try StorageOverviewResolver.locations(
			paths: paths,
			context: StorageOverviewContext(
				region: .global,
				regionAccess: RegionAccess(
					canaryFeaturesEnabled: canary, taiwanClientEnabled: canary),
				persistedInstallDirectories: [:]
			)
		)
		#expect(filtered.contains { $0.category == .game(.taiwan) } == canary)
		#expect(filtered.contains { $0.category == .game(.china) })
	}
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
	let lease = lifecycle.begin(.installing(id: UUID(), stage: .downloading))
	#expect(lease != nil)

	storage.clearPresetGalleryCache()

	#expect(lifecycle.activity.isInstalling)
}

@Test
@MainActor
func persistedStorageMeasurementSeedsTheNextOpenUntilItIsReplaced() async throws {
	let temporary = try TemporaryDirectory("StorageOverviewTests")
	defer { temporary.remove() }
	let root = temporary.url
	let log = LauncherLog(fileURL: root.appending(path: "launcher.log"))
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support"),
		cachesDirectory: root.appending(path: "Caches"),
		libraryDirectory: root.appending(path: "Library"),
		resourceDirectory: root.appending(path: "Resources")
	)
	let (defaults, suiteName) = makeIsolatedDefaults("StorageOverviewTests")
	defer { defaults.removePersistentDomain(forName: suiteName) }
	let preferences = LauncherPreferencesStore(defaults: defaults)
	let context = StorageOverviewResolver.context(preferences: preferences, region: .global)
	let store = StorageOverviewCacheStore(fileURL: paths.storageOverviewCache, log: log)
	// The persisted size differs from the real one, so each assertion shows which value is visible.
	let persistedLogs = StorageUsage(
		location: StorageLocation(category: .logs, urls: []),
		byteCount: 999,
		exists: true
	)
	await store.save([
		StorageOverviewCacheEntry(
			key: StorageOverviewCacheKey(context: context),
			usages: [CachedStorageUsage(persistedLogs)]
		)
	])
	try FileManager.default.createDirectory(
		at: paths.logsDirectory,
		withIntermediateDirectories: true
	)
	try Data(count: 7).write(to: paths.logsDirectory.appending(path: "sample.bin"))

	let controller = StorageOverviewController(
		lifecycle: LauncherLifecycleStore(log: log),
		paths: paths,
		preferences: preferences,
		log: log
	)
	controller.refresh()

	#expect(controller.isMeasuring)
	#expect(controller.usage(for: .logs)?.byteCount == 999)
	#expect(await waitForCondition { !controller.isMeasuring })
	#expect(controller.usage(for: .logs)?.byteCount == 7)
	// Wait for the write too, so it cannot recreate the temporary directory after cleanup.
	let logsID = StorageCategory.logs.id
	#expect(
		await waitForCondition {
			store.loadSynchronously().first?.usages.first { $0.categoryID == logsID }?
				.byteCount == 7
		})
}
