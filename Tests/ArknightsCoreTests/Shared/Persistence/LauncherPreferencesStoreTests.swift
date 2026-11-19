// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore
@testable import ArknightsInfrastructure

private typealias Key = LauncherPreferencesStore.Key

private struct StoredShortcutCase: Sendable {
	let shortcut: ScreenshotShortcut
	let stored: String
}

@MainActor
struct LauncherPreferencesStoreTests {
	@Test
	func launchOptionsKeepValidStoredFieldsAndDefaultAnUnsupportedResolution() {
		let (defaults, suiteName) = makeIsolatedDefaults("LauncherPreferencesStoreTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(
			defaults: defaults, themeCacheURL: makeUnusedThemeCacheURL())
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
	}

	@Test(
		arguments: [
			StoredShortcutCase(shortcut: .off, stored: "off"),
			StoredShortcutCase(shortcut: .standard, stored: "standard"),
			StoredShortcutCase(
				shortcut: .custom(
					HotKeyCombination(keyCode: HotKeyCombination.keyCodeF13), label: "F13"),
				stored: "custom:105:0:F13"),
			StoredShortcutCase(
				shortcut: .custom(
					HotKeyCombination(
						keyCode: HotKeyCombination.keyCodeS, modifiers: [.control, .command]),
					label: "S"),
				stored: "custom:1:4352:S"),
			// The label may contain ":", so the parser must split at most three times.
			StoredShortcutCase(
				shortcut: .custom(
					HotKeyCombination(keyCode: 41, modifiers: [.shift, .option]), label: ":"),
				stored: "custom:41:2560::"),
		])
	private func screenshotShortcutRoundTripsThroughStorage(_ testCase: StoredShortcutCase) {
		let (defaults, suiteName) = makeIsolatedDefaults("LauncherPreferencesStoreTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(
			defaults: defaults, themeCacheURL: makeUnusedThemeCacheURL())

		store.setScreenshotShortcut(testCase.shortcut)

		#expect(defaults.string(forKey: Key.screenshotShortcut) == testCase.stored)
		#expect(store.screenshotShortcut() == testCase.shortcut)
	}

	@Test
	func installDirectoryMigrationPreservesSeparateRegionalUserChoices() {
		let (defaults, suiteName) = makeIsolatedDefaults("LauncherPreferencesStoreTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(
			defaults: defaults, themeCacheURL: makeUnusedThemeCacheURL())
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
	func resetKeepsRegionInstallLocationsAndTheMigrationVersion() {
		let (defaults, suiteName) = makeIsolatedDefaults("LauncherPreferencesStoreTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(
			defaults: defaults, themeCacheURL: makeUnusedThemeCacheURL())
		defaults.set("/Games/Global", forKey: Key.installPath(for: .global))
		defaults.set("japan", forKey: Key.selectedRegion)
		defaults.set(4, forKey: Key.preferencesMigrationVersion)
		store.set(false, for: Key.automaticLauncherUpdates)
		store.setScreenshotShortcut(.standard)

		store.removeResettablePreferences()

		#expect(defaults.object(forKey: Key.automaticLauncherUpdates.name) == nil)
		#expect(defaults.object(forKey: Key.screenshotShortcut) == nil)
		#expect(defaults.string(forKey: Key.installPath(for: .global)) == "/Games/Global")
		#expect(defaults.string(forKey: Key.selectedRegion) == "japan")
		#expect(defaults.integer(forKey: Key.preferencesMigrationVersion) == 4)
	}
}
