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
		#expect(!store.followsDefaultAudioOutput())
		#expect(store.maximumFrameLatency() == 3)
		#expect(store.selectedRegion() == .global)
		#expect(store.appLanguage() == .system)
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
		store.setFollowsDefaultAudioOutput(true)
		store.setMaximumFrameLatency(1)
		store.setSelectedRegion(.korea)
		store.setAppLanguage(.german)

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
		#expect(store.followsDefaultAudioOutput())
		#expect(store.maximumFrameLatency() == 1)
		#expect(store.selectedRegion() == .korea)
		#expect(store.appLanguage() == .german)
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
	}

	@Test
	func launchOptionsRoundTrip() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		let expected = GameLaunchOptions(
			displayMode: .borderlessWindow,
			resolution: .quadHD,
			synchronizationMode: .esync
		)

		store.setLaunchOptions(expected)

		#expect(store.launchOptions() == expected)
	}

	@Test
	func installDirectoriesAreIndependentPerRegion() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		let global = URL(filePath: "/tmp/Global", directoryHint: .isDirectory)
		let japan = URL(filePath: "/tmp/Japan", directoryHint: .isDirectory)
		let fallback = URL(filePath: "/tmp/Fallback", directoryHint: .isDirectory)

		store.setInstallDirectory(global, for: .global)
		store.setInstallDirectory(japan, for: .japan)

		#expect(store.installDirectory(for: .global, default: fallback) == global)
		#expect(store.installDirectory(for: .japan, default: fallback) == japan)
		#expect(store.installDirectory(for: .korea, default: fallback) == fallback)
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
