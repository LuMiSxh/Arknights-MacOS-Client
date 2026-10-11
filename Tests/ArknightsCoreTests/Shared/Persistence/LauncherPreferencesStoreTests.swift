// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

private typealias Key = LauncherPreferencesStore.Key

@MainActor
struct LauncherPreferencesStoreTests {
	@Test
	func scalarPreferencesUseDefaultsAndPersistChanges() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		#expect(store.value(Key.automaticLauncherUpdates))
		#expect(store.value(Key.automaticGameUpdates))
		#expect(store.value(Key.announcementsEnabled))
		#expect(!store.value(Key.showsServerResetCountdown))
		#expect(store.value(Key.showsGameVersion))
		#expect(store.value(Key.showsBranding))
		#expect(store.value(Key.playsLauncherMusic))
		#expect(!store.value(Key.showsPlayingMusic))
		#expect(store.value(Key.launcherMusicURL) == AppConstants.Music.defaultLauncherMusicURL)
		#expect(store.value(Key.launcherMusicVolume) == 0.5)
		#expect(store.value(Key.usesDynamicTheme))
		#expect(!store.value(Key.canaryFeaturesEnabled))
		#expect(!store.value(Key.taiwanClientEnabled))
		#expect(store.selectedRegion() == .global)
		#expect(!store.forceDisableRetina())

		store.set(false, for: Key.automaticLauncherUpdates)
		store.set(false, for: Key.automaticGameUpdates)
		store.set(false, for: Key.announcementsEnabled)
		store.set(true, for: Key.showsServerResetCountdown)
		store.set(false, for: Key.showsGameVersion)
		store.set(false, for: Key.showsBranding)
		store.set(false, for: Key.playsLauncherMusic)
		store.set(true, for: Key.showsPlayingMusic)
		store.set("https://youtube.com/playlist?list=123", for: Key.launcherMusicURL)
		store.set(0.8, for: Key.launcherMusicVolume)
		store.set(false, for: Key.usesDynamicTheme)
		store.set(true, for: Key.canaryFeaturesEnabled)
		store.set(true, for: Key.taiwanClientEnabled)
		store.setSelectedRegion(.korea)

		#expect(!store.value(Key.automaticLauncherUpdates))
		#expect(!store.value(Key.automaticGameUpdates))
		#expect(!store.value(Key.announcementsEnabled))
		#expect(store.value(Key.showsServerResetCountdown))
		#expect(!store.value(Key.showsGameVersion))
		#expect(!store.value(Key.showsBranding))
		#expect(!store.value(Key.playsLauncherMusic))
		#expect(store.value(Key.showsPlayingMusic))
		#expect(store.value(Key.launcherMusicURL) == "https://youtube.com/playlist?list=123")
		#expect(store.value(Key.launcherMusicVolume) == 0.8)
		#expect(!store.value(Key.usesDynamicTheme))
		#expect(store.value(Key.canaryFeaturesEnabled))
		#expect(store.value(Key.taiwanClientEnabled))
		#expect(store.selectedRegion() == .korea)
	}

	@Test
	func runtimeToggleAndDisplayNoteDefaultOffAndPersist() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		#expect(!store.value(Key.usesHardwareCursor))
		#expect(!store.value(Key.dismissedInGameResolutionNote))

		store.set(true, for: Key.usesHardwareCursor)
		store.set(true, for: Key.dismissedInGameResolutionNote)

		let reloaded = LauncherPreferencesStore(defaults: defaults)
		#expect(reloaded.value(Key.usesHardwareCursor))
		#expect(reloaded.value(Key.dismissedInGameResolutionNote))
	}

	@Test
	func resettingPreferencesRestoresRuntimeToggleAndDisplayNote() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		let settings = LauncherPreferencesController(store: store)
		settings.usesHardwareCursor = true
		settings.dismissedInGameResolutionNote = true

		#expect(settings.resetToDefaults(canModifyLaunchOptions: true))
		#expect(!settings.usesHardwareCursor)
		#expect(!store.value(Key.usesHardwareCursor))
		#expect(!settings.dismissedInGameResolutionNote)
		#expect(!store.value(Key.dismissedInGameResolutionNote))
	}

	@Test
	func chinaSelectionIsIndependentOfCanaryPermissions() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		for region in [GameRegion.china, .chinaBilibili] {
			store.setSelectedRegion(region)
			#expect(store.selectedRegion() == region)
		}

		store.set(true, for: Key.canaryFeaturesEnabled)
		store.set(false, for: Key.canaryFeaturesEnabled)
		#expect(store.selectedRegion() == .chinaBilibili)
	}

	@Test(arguments: [true, false])
	func legacyChinaPermissionKeysDoNotAffectRegionAccess(legacyChinaPermission: Bool) {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		defaults.set(legacyChinaPermission, forKey: "chinaClientsEnabled")
		defaults.set(true, forKey: "canaryFeaturesEnabled")
		defaults.set(GameRegion.china.rawValue, forKey: "selectedRegion")

		let store = LauncherPreferencesStore(defaults: defaults)
		#expect(store.selectedRegion() == .china)
		#expect(!store.value(Key.taiwanClientEnabled))
	}

	@Test
	func taiwanSelectionRequiresTaiwanAndCanaryPermissions() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		store.setSelectedRegion(.taiwan)
		#expect(store.selectedRegion() == .global)

		store.set(true, for: Key.canaryFeaturesEnabled)
		#expect(store.selectedRegion() == .global)

		store.set(true, for: Key.taiwanClientEnabled)
		#expect(store.selectedRegion() == .taiwan)

		store.set(false, for: Key.taiwanClientEnabled)
		#expect(store.selectedRegion() == .global)
	}

	@Test
	func aceWarningAcknowledgementsPersistPerRegion() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		#expect(!store.hasAcknowledgedACEWarning(for: .china))
		#expect(!store.hasAcknowledgedACEWarning(for: .chinaBilibili))

		store.markACEWarningAcknowledged(for: .china)

		#expect(store.hasAcknowledgedACEWarning(for: .china))
		#expect(!store.hasAcknowledgedACEWarning(for: .chinaBilibili))
	}

	@Test
	func announcementHistoryPersistsAndCapsIDs() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		for index in 0..<110 {
			store.markAnnouncementSeen("message-\(index)")
		}
		#expect(store.seenAnnouncementIDs().count == 100)
		#expect(store.seenAnnouncementIDs().contains("message-109"))
		#expect(!store.seenAnnouncementIDs().contains("message-9"))

		store.markAnnouncementSeen("message-10")
		store.markAnnouncementSeen("new")
		#expect(store.seenAnnouncementIDs().contains("message-10"))
		#expect(!store.seenAnnouncementIDs().contains("message-11"))
	}

	@Test
	func launchOptionsPreserveValidStoredFieldsAndRoundTrip() {
		let (defaults, suiteName) = makeDefaults()
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
	func musicVolumeIsClampedWhenPersistedValueIsOutsideTheSupportedRange() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		store.set(-0.25, for: Key.launcherMusicVolume)
		#expect(store.value(Key.launcherMusicVolume) == 0)

		store.set(1.25, for: Key.launcherMusicVolume)
		#expect(store.value(Key.launcherMusicVolume) == 1)

		store.set(.infinity, for: Key.launcherMusicVolume)
		#expect(store.value(Key.launcherMusicVolume) == 0.5)
	}

	@Test
	func installDirectoryMigrationPreservesSeparateRegionalUserChoices() {
		let (defaults, suiteName) = makeDefaults()
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
	func dynamicThemeAccentsPersistPerArtworkSource() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		let global = ThemeAccentSnapshot(hue: 0.03, saturation: 0.7, brightness: 0.8)
		let custom = ThemeAccentSnapshot(hue: 0.55, saturation: 0.6, brightness: 0.7)

		store.setDynamicThemeAccent(global, for: "official.global")
		store.setDynamicThemeAccent(custom, for: "custom")

		#expect(store.dynamicThemeAccent(for: "official.global") == global)
		#expect(store.dynamicThemeAccent(for: "custom") == custom)
		#expect(store.dynamicThemeAccent(for: "official.korea") == nil)
	}

	private func makeDefaults() -> (UserDefaults, String) {
		let suiteName = "LauncherPreferencesStoreTests.\(UUID().uuidString)"
		return (UserDefaults(suiteName: suiteName)!, suiteName)
	}
}
