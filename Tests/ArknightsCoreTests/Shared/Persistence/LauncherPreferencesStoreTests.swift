// SPDX-License-Identifier: MPL-2.0

import ArknightsInfrastructure
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

private typealias Key = LauncherPreferencesStore.Key

private struct StoredShortcutCase: Sendable {
	let shortcut: ScreenshotShortcut
	let stored: String
}

@MainActor
struct LauncherPreferencesStoreTests {
	@Test
	func launchOptionsPreserveValidStoredFieldsAndRoundTrip() throws {
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

		try store.setLaunchOptions(expected)

		#expect(store.launchOptions() == expected)
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
		let store = LauncherPreferencesStore(defaults: defaults)

		store.setScreenshotShortcut(testCase.shortcut)

		#expect(defaults.string(forKey: Key.screenshotShortcut) == testCase.stored)
		#expect(store.screenshotShortcut() == testCase.shortcut)
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
	func appearancePreferencesRoundTripAndFallBackForUnknownValues() {
		let (defaults, suiteName) = makeIsolatedDefaults("LauncherPreferencesStoreTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		#expect(store.launcherAppearance() == .system)
		#expect(store.homeTheme() == .automatic)
		#expect(store.brandingTheme() == .automatic)

		for appearance in LauncherAppearance.allCases {
			store.setLauncherAppearance(appearance)
			#expect(store.launcherAppearance() == appearance)
		}
		for theme in HomeTheme.allCases {
			store.setHomeTheme(theme)
			#expect(store.homeTheme() == theme)
			store.setBrandingTheme(theme)
			#expect(store.brandingTheme() == theme)
		}

		defaults.set("unknown", forKey: Key.launcherAppearance)
		defaults.set("unknown", forKey: Key.homeTheme)
		defaults.set("unknown", forKey: Key.brandingTheme)
		#expect(store.launcherAppearance() == .system)
		#expect(store.homeTheme() == .automatic)
		#expect(store.brandingTheme() == .automatic)
	}

	@Test
	func homeLuminanceRoundTripsThroughTheStoredDictionaryFormat() {
		let (defaults, suiteName) = makeIsolatedDefaults("LauncherPreferencesStoreTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		let stored: [[String: Any]] = [
			["identity": "old", "score": 0.25],
			["identity": "new", "score": 0.75],
		]
		defaults.set(stored, forKey: "homeLuminanceCache")

		#expect(store.homeLuminance(for: "new") == 0.75)

		store.setHomeLuminance(0.5, for: "old", limit: 2)

		let written = defaults.array(forKey: "homeLuminanceCache") as? [[String: Any]] ?? []
		#expect(written.map { $0["identity"] as? String } == ["new", "old"])
		#expect(written.map { $0["score"] as? Double } == [0.75, 0.5])
		#expect(store.homeLuminance(for: "old") == 0.5)
	}

	@Test
	func runtimePatchesDefaultOnAndStoreOneSwitchEach() {
		let (defaults, suiteName) = makeIsolatedDefaults("LauncherPreferencesStoreTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		#expect(RuntimePatch.allCases.allSatisfy { store.value(Key.runtimePatchEnabled($0)) })
		store.set(false, for: Key.runtimePatchEnabled(.winsock))

		#expect(defaults.object(forKey: "runtimePatch.winsock") as? Bool == false)
		#expect(store.value(Key.runtimePatchEnabled(.menu)))
	}

	@Test
	func resetRemovesExactlyTheResettablePreferences() {
		let (defaults, suiteName) = makeIsolatedDefaults("LauncherPreferencesStoreTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		for preference in Key.all {
			defaults.set("stored", forKey: preference.name)
		}

		store.removeResettablePreferences()

		for preference in Key.all {
			let removed = defaults.object(forKey: preference.name) == nil
			#expect(removed == preference.resettable, "\(preference.name)")
		}
	}
}
