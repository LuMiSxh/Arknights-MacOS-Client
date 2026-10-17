// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

private typealias Key = LauncherPreferencesStore.Key

@MainActor
struct LauncherPreferencesStoreTests {
	@Test
	func launchOptionsPreserveValidStoredFieldsAndRoundTrip() {
		let (defaults, suiteName) = makeIsolatedDefaults("LauncherPreferencesStoreTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		defaults.set(
			Data(
				#"{"displayMode":"borderlessWindow","resolution":"9999x9999","usesGameMode":true}"#
					.utf8),
			forKey: "gameLaunchOptions"
		)

		let options = store.launchOptions()

		#expect(options.displayMode == .borderlessWindow)
		#expect(options.resolution == GameLaunchOptions.default.resolution)
		#expect(options.usesGameMode)

		let expected = GameLaunchOptions(
			displayMode: .borderlessWindow,
			resolution: .quadHD,
			synchronizationMode: .esync
		)

		store.setLaunchOptions(expected)

		#expect(store.launchOptions() == expected)
	}

	@Test
	func installDirectoryMigrationPreservesSeparateRegionalUserChoices() {
		let (defaults, suiteName) = makeIsolatedDefaults("LauncherPreferencesStoreTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		let legacyGlobal = URL(filePath: "/tmp/Legacy-Global", directoryHint: .isDirectory)
		let legacyJapan = URL(filePath: "/tmp/Legacy-Japan", directoryHint: .isDirectory)
		let fallback = URL(filePath: "/tmp/Fallback", directoryHint: .isDirectory)

		store.setInstallDirectory(legacyGlobal, for: .global)
		store.setInstallDirectory(legacyJapan, for: .japan)

		#expect(store.installDirectory(for: .global, default: fallback) == legacyGlobal)
		#expect(store.installDirectory(for: .japan, default: fallback) == legacyJapan)
		#expect(store.installDirectory(for: .korea, default: fallback) == fallback)
		let customJapan = URL(filePath: "/tmp/Custom-Japan", directoryHint: .isDirectory)
		let currentGlobal = URL(filePath: "/tmp/Yostar/Global", directoryHint: .isDirectory)
		let currentJapan = URL(filePath: "/tmp/Yostar/Japan", directoryHint: .isDirectory)
		let snapshot = store.persistedInstallDirectories()
		store.setInstallDirectory(customJapan, for: .japan)

		store.updateInstallDirectories(
			[.global: currentGlobal, .japan: currentJapan], replacing: snapshot)

		#expect(store.installDirectory(for: .global, default: legacyGlobal) == currentGlobal)
		#expect(store.installDirectory(for: .japan, default: legacyJapan) == customJapan)
	}

	@Test
	func removeLegacyDynamicThemeAccentsKeepsOnlyCurrentVersionEntries() {
		let (defaults, suiteName) = makeIsolatedDefaults("LauncherPreferencesStoreTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		defaults.set(
			["hue": 0.1, "saturation": 0.8, "brightness": 0.9],
			forKey: "dynamicThemeAccent.legacy-cache"
		)
		store.setDynamicThemeAccent(
			ThemeAccentSnapshot(hue: 0.6, saturation: 0.8, brightness: 0.9),
			for: "current-cache"
		)

		store.removeLegacyDynamicThemeAccents()

		#expect(defaults.object(forKey: "dynamicThemeAccent.legacy-cache") == nil)
		#expect(store.dynamicThemeAccent(for: "current-cache")?.hue == 0.6)
	}

}
