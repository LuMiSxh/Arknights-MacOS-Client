// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherPreferencesStoreTests {
	@Test
	func scalarPreferencesUseDefaultsAndPersistChanges() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		#expect(store.automaticLauncherUpdates())
		#expect(store.automaticGameUpdates())
		#expect(store.announcementsEnabled())
		#expect(!store.showsServerResetCountdown())
		#expect(store.showsGameVersion())
		#expect(store.playsLauncherMusic())
		#expect(!store.showsPlayingMusic())
		#expect(store.launcherMusicURL() == AppConstants.Music.defaultLauncherMusicURL)
		#expect(store.launcherMusicVolume() == 0.5)
		#expect(store.usesDynamicTheme())
		#expect(!store.canaryFeaturesEnabled())
		#expect(!store.chinaClientsEnabled())
		#expect(!store.taiwanClientEnabled())
		#expect(store.maximumFrameLatency() == 3)
		#expect(store.selectedRegion() == .global)
		#expect(!store.forceDisableRetina())

		store.setAutomaticLauncherUpdates(false)
		store.setAutomaticGameUpdates(false)
		store.setAnnouncementsEnabled(false)
		store.setShowsServerResetCountdown(true)
		store.setShowsGameVersion(false)
		store.setPlaysLauncherMusic(false)
		store.setShowsPlayingMusic(true)
		store.setLauncherMusicURL("https://youtube.com/playlist?list=123")
		store.setLauncherMusicVolume(0.8)
		store.setUsesDynamicTheme(false)
		store.setCanaryFeaturesEnabled(true)
		store.setChinaClientsEnabled(true)
		store.setTaiwanClientEnabled(true)
		store.setMaximumFrameLatency(1)
		store.setSelectedRegion(.korea)

		#expect(!store.automaticLauncherUpdates())
		#expect(!store.automaticGameUpdates())
		#expect(!store.announcementsEnabled())
		#expect(store.showsServerResetCountdown())
		#expect(!store.showsGameVersion())
		#expect(!store.playsLauncherMusic())
		#expect(store.showsPlayingMusic())
		#expect(store.launcherMusicURL() == "https://youtube.com/playlist?list=123")
		#expect(store.launcherMusicVolume() == 0.8)
		#expect(!store.usesDynamicTheme())
		#expect(store.canaryFeaturesEnabled())
		#expect(store.chinaClientsEnabled())
		#expect(store.taiwanClientEnabled())
		#expect(store.maximumFrameLatency() == 1)
		#expect(store.selectedRegion() == .korea)
	}

	@Test
	func hardwareCursorPreferenceDefaultsOffAndPersists() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		#expect(!store.usesHardwareCursor())

		store.setUsesHardwareCursor(true)

		#expect(LauncherPreferencesStore(defaults: defaults).usesHardwareCursor())
	}

	@Test
	func resettingPreferencesDisablesHardwareCursor() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		let settings = LauncherPreferencesController(store: store)
		settings.usesHardwareCursor = true

		#expect(settings.resetToDefaults(canModifyLaunchOptions: true))
		#expect(!settings.usesHardwareCursor)
		#expect(!store.usesHardwareCursor())
	}

	@Test(arguments: [(-1, 0), (0, 0), (2, 2), (4, 3)])
	func frameLatencyClampsToSupportedRange(value: Int, expected: Int) {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		store.setMaximumFrameLatency(value)

		#expect(store.maximumFrameLatency() == expected)
	}

	@Test
	func chinaSelectionFallsBackWhenEitherPermissionIsDisabled() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		store.setCanaryFeaturesEnabled(true)
		store.setChinaClientsEnabled(true)
		store.setSelectedRegion(.china)
		#expect(store.selectedRegion() == .china)

		store.setChinaClientsEnabled(false)
		#expect(store.selectedRegion() == .global)

		store.setChinaClientsEnabled(true)
		store.setSelectedRegion(.china)
		store.setCanaryFeaturesEnabled(false)
		#expect(store.selectedRegion() == .global)
	}

	@Test
	func taiwanSelectionRequiresTaiwanAndCanaryPermissions() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		store.setSelectedRegion(.taiwan)
		#expect(store.selectedRegion() == .global)

		store.setCanaryFeaturesEnabled(true)
		#expect(store.selectedRegion() == .global)

		store.setTaiwanClientEnabled(true)
		#expect(store.selectedRegion() == .taiwan)

		store.setTaiwanClientEnabled(false)
		#expect(store.selectedRegion() == .global)
	}

	@Test
	func chinaAndTaiwanSelectionsUseIndependentPermissions() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		store.setCanaryFeaturesEnabled(true)
		store.setTaiwanClientEnabled(true)
		store.setSelectedRegion(.taiwan)
		#expect(store.selectedRegion() == .taiwan)

		store.setSelectedRegion(.china)
		#expect(store.selectedRegion() == .global)

		store.setChinaClientsEnabled(true)
		#expect(store.selectedRegion() == .china)

		store.setTaiwanClientEnabled(false)
		#expect(store.selectedRegion() == .china)
	}

	@Test(arguments: [
		(
			"legacy canary access keeps the saved Yostar region",
			true,
			Optional<Bool>.none,
			GameRegion.global,
			true,
			GameRegion.global,
			true
		),
		(
			"legacy canary access keeps the saved China region",
			true,
			Optional<Bool>.none,
			GameRegion.china,
			true,
			GameRegion.china,
			true
		),
		(
			"legacy canary access keeps the saved Bilibili region",
			true,
			Optional<Bool>.none,
			GameRegion.chinaBilibili,
			true,
			GameRegion.chinaBilibili,
			true
		),
		(
			"an explicit China opt-out survives migration",
			true,
			false as Bool?,
			GameRegion.china,
			false,
			GameRegion.global,
			false
		),
		(
			"an explicit China opt-in survives migration",
			true,
			true as Bool?,
			GameRegion.china,
			true,
			GameRegion.china,
			false
		),
		(
			"a missing legacy canary value grants no China access",
			Optional<Bool>.none,
			Optional<Bool>.none,
			GameRegion.global,
			false,
			GameRegion.global,
			false
		),
		(
			"a disabled legacy canary value grants no China access",
			false as Bool?,
			Optional<Bool>.none,
			GameRegion.global,
			false,
			GameRegion.global,
			false
		),
	])
	func chinaPermissionMigrationKeepsCanaryAndExplicitAccessIndependent(
		caseLabel: String,
		legacyCanary: Bool?,
		legacyChinaPermission: Bool?,
		selectedRegion: GameRegion,
		expectedChinaPermission: Bool,
		expectedRegion: GameRegion,
		verifyLegacyPermissionOptOut: Bool
	) {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		if let legacyCanary {
			defaults.set(legacyCanary, forKey: "canaryFeaturesEnabled")
		}
		if let legacyChinaPermission {
			defaults.set(legacyChinaPermission, forKey: "chinaClientsEnabled")
		}
		defaults.set(selectedRegion.rawValue, forKey: "selectedRegion")

		let store = LauncherPreferencesStore(defaults: defaults)
		#expect(
			store.chinaClientsEnabled() == expectedChinaPermission, Comment(rawValue: caseLabel))
		#expect(store.selectedRegion() == expectedRegion, Comment(rawValue: caseLabel))
		#expect(!store.taiwanClientEnabled())
		#expect(!store.hasAcknowledgedACEWarning(for: .china))
		#expect(!store.hasAcknowledgedACEWarning(for: .chinaBilibili))

		store.setCanaryFeaturesEnabled(true)
		let reopened = LauncherPreferencesStore(defaults: defaults)
		#expect(
			reopened.chinaClientsEnabled() == expectedChinaPermission, Comment(rawValue: caseLabel))
		#expect(reopened.selectedRegion() == expectedRegion, Comment(rawValue: caseLabel))
		#expect(!reopened.taiwanClientEnabled())

		if verifyLegacyPermissionOptOut {
			reopened.setChinaClientsEnabled(false)
			let optedOut = LauncherPreferencesStore(defaults: defaults)
			#expect(!optedOut.chinaClientsEnabled(), Comment(rawValue: caseLabel))
			#expect(optedOut.selectedRegion() == .global, Comment(rawValue: caseLabel))
		}
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

		store.setLauncherMusicVolume(-0.25)
		#expect(store.launcherMusicVolume() == 0)

		store.setLauncherMusicVolume(1.25)
		#expect(store.launcherMusicVolume() == 1)

		store.setLauncherMusicVolume(.infinity)
		#expect(store.launcherMusicVolume() == 0.5)
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
