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
	let root = temporaryStorageRoot()
	defer { try? FileManager.default.removeItem(at: root) }
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
	let lease = lifecycle.begin(.installing(id: UUID(), stage: .downloading))
	#expect(lease != nil)

	storage.clearPresetGalleryCache()

	#expect(lifecycle.activity.isInstalling)
}

private func temporaryStorageRoot() -> URL {
	FileManager.default.temporaryDirectory.appending(
		path: "StorageOverviewTests.\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
}
