// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Synchronization
import Testing

@testable import ArknightsCore

private func makeThemeCacheURL(_ label: String) -> URL {
	FileManager.default.temporaryDirectory
		.appending(path: "\(label)-\(UUID().uuidString)", directoryHint: .isDirectory)
		.appending(path: "theme.json")
}

@MainActor
struct PreferencesMigratorTests {
	@Test
	func pendingStepsRunOnceInOrderAndRecordTheVersion() {
		let (defaults, suiteName) = makeIsolatedDefaults("PreferencesMigratorTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let ran = Mutex<[Int]>([])
		let migrator = PreferencesMigrator(steps: [
			.init(version: 1) { _ in ran.withLock { $0.append(1) } },
			.init(version: 2) { _ in ran.withLock { $0.append(2) } },
			.init(version: 3) { _ in ran.withLock { $0.append(3) } },
		])
		defaults.set(1, forKey: LauncherPreferencesStore.Key.preferencesMigrationVersion)

		migrator.migrate(defaults, themeCacheURL: makeThemeCacheURL("CustomSteps"))
		migrator.migrate(defaults, themeCacheURL: makeThemeCacheURL("CustomSteps"))

		#expect(ran.withLock { $0 } == [2, 3])
		#expect(
			defaults.integer(forKey: LauncherPreferencesStore.Key.preferencesMigrationVersion) == 3)
	}

	@Test
	func retiredKeysAreRemovedForAnOlderInstall() {
		let (defaults, suiteName) = makeIsolatedDefaults("PreferencesMigratorTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		// 0.7.1 recorded version 2 and never ran the 0.8 development steps.
		defaults.set(2, forKey: LauncherPreferencesStore.Key.preferencesMigrationVersion)
		defaults.set(["hue": 0.1], forKey: "dynamicThemeAccent.v2.legacy-cache")
		defaults.set(["hue": 0.2], forKey: "dynamicThemeAccent.v4.current-cache")
		defaults.set([["identity": "old", "score": 0.5]], forKey: "homeLuminanceCache")
		defaults.set(true, forKey: "forceDisableRetina")
		defaults.set(true, forKey: "canaryFeaturesEnabled")

		PreferencesMigrator().migrate(
			defaults, themeCacheURL: makeThemeCacheURL("RetiredTheme"))

		#expect(defaults.object(forKey: "dynamicThemeAccent.v2.legacy-cache") == nil)
		#expect(defaults.object(forKey: "dynamicThemeAccent.v4.current-cache") == nil)
		#expect(defaults.object(forKey: "homeLuminanceCache") == nil)
		#expect(defaults.object(forKey: "forceDisableRetina") == nil)
		#expect(defaults.object(forKey: "canaryFeaturesEnabled") == nil)
		#expect(
			defaults.integer(forKey: LauncherPreferencesStore.Key.preferencesMigrationVersion) == 4)
	}

	@Test
	func validLegacyThemeValuesMoveIntoTheThemeCache() throws {
		let temporary = try TemporaryDirectory("PreferencesMigratorTests")
		defer { temporary.remove() }
		let (defaults, suiteName) = makeIsolatedDefaults("PreferencesMigratorTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		// 0.8 development builds kept these values in preferences before the theme file existed.
		defaults.set(2, forKey: LauncherPreferencesStore.Key.preferencesMigrationVersion)
		defaults.set(
			["hue": 0.2, "saturation": 0.5, "brightness": 0.9],
			forKey: "dynamicThemeAccent.v4.current-cache")
		let identity = "\(AppConstants.Theme.homeLuminanceVersion).art"
		defaults.set(
			[
				["identity": identity, "score": 0.5],
				["identity": "homeLuminance.v0.old", "score": 0.7],
			],
			forKey: "homeLuminanceCache")
		let url = temporary.url.appending(path: "Theme/theme.json")

		PreferencesMigrator().migrate(defaults, themeCacheURL: url)

		let store = LauncherPreferencesStore(defaults: defaults, themeCacheURL: url)
		#expect(store.dynamicThemeAccent(for: "current-cache")?.hue == 0.2)
		#expect(store.homeLuminance(for: identity) == 0.5)
		#expect(store.homeLuminance(for: "homeLuminance.v0.old") == nil)
		#expect(defaults.object(forKey: "homeLuminanceCache") == nil)
	}

	@Test
	func stepsAreOrderedByIncreasingVersion() {
		let steps = PreferencesMigrator.steps
		#expect(zip(steps, steps.dropFirst()).allSatisfy { $0.version < $1.version })
	}

	@Test(arguments: [
		// Retina on: the stored resolution was in pixels, so the window is half its size.
		(
			#"{"resolution":"2560x1440","usesGameSettings":false}"#,
			GameLaunchOptions(
				displayMode: .windowed,
				resolution: .quadHD,
				windowSize: GameDisplaySize(width: 1280, height: 720),
				usesGameSettings: false,
				renderingMode: .retina
			)
		),
		// Retina off: the stored pixels were the window.
		(
			#"{"resolution":"1920x1080","usesGameSettings":false,"usesHighResolutionMode":false}"#,
			GameLaunchOptions(
				displayMode: .windowed,
				resolution: .fullHD,
				windowSize: GameDisplaySize(width: 1920, height: 1080),
				usesGameSettings: false,
				renderingMode: .standard
			)
		),
		// In-game settings never used the stored resolution, so the window starts at the default.
		(
			#"{"resolution":"2560x1440","usesGameSettings":true}"#,
			GameLaunchOptions(
				displayMode: .windowed,
				resolution: .quadHD,
				usesGameSettings: true,
				renderingMode: .retina
			)
		),
		// Halving below the smallest supported window falls back to the default size.
		(
			#"{"resolution":"640x480","usesGameSettings":false}"#,
			GameLaunchOptions(
				displayMode: .windowed,
				resolution: GameDisplaySize(width: 640, height: 480),
				usesGameSettings: false,
				renderingMode: .retina
			)
		),
		// An unreadable window size falls back to the default size.
		(
			#"{"windowSize":{"width":10,"height":10},"usesGameSettings":false}"#,
			GameLaunchOptions(
				displayMode: .windowed,
				resolution: GameLaunchOptions.default.resolution,
				usesGameSettings: false,
				renderingMode: .retina
			)
		),
		// Stored options without usesGameSettings predate it, when Arknights kept its own settings.
		(
			#"{"displayMode":"fullscreen","resolution":"1280x720"}"#,
			GameLaunchOptions(
				displayMode: .fullscreen,
				resolution: .hd,
				usesGameSettings: true,
				renderingMode: .retina
			)
		),
	])
	func legacyLaunchOptionsKeepTheirEffectiveSettingsAfterMigration(
		json: String, expected: GameLaunchOptions
	) {
		let (defaults, suiteName) = makeIsolatedDefaults("PreferencesMigratorTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		defaults.set(Data(json.utf8), forKey: LauncherPreferencesStore.Key.gameLaunchOptions)

		let themeCacheURL = makeThemeCacheURL("LaunchOptions")
		PreferencesMigrator().migrate(defaults, themeCacheURL: themeCacheURL)

		#expect(
			LauncherPreferencesStore(defaults: defaults, themeCacheURL: themeCacheURL)
				.launchOptions() == expected)
	}
}
