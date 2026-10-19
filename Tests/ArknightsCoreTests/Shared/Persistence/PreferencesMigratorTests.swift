// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Synchronization
import Testing

@testable import ArknightsCore

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

		migrator.migrate(defaults)
		migrator.migrate(defaults)

		#expect(ran.withLock { $0 } == [2, 3])
		#expect(
			defaults.integer(forKey: LauncherPreferencesStore.Key.preferencesMigrationVersion) == 3)
	}

	@Test
	func legacyThemeAccentsAreRemovedAndCurrentOnesStay() {
		let (defaults, suiteName) = makeIsolatedDefaults("PreferencesMigratorTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		defaults.set(["hue": 0.1], forKey: "dynamicThemeAccent.legacy-cache")
		store.setDynamicThemeAccent(
			ThemeAccentSnapshot(hue: 0.6, saturation: 0.8, brightness: 0.9), for: "current-cache")

		PreferencesMigrator().migrate(defaults)

		#expect(defaults.object(forKey: "dynamicThemeAccent.legacy-cache") == nil)
		#expect(store.dynamicThemeAccent(for: "current-cache")?.hue == 0.6)
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

		PreferencesMigrator().migrate(defaults)

		#expect(LauncherPreferencesStore(defaults: defaults).launchOptions() == expected)
	}
}
