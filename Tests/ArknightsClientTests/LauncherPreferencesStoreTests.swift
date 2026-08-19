// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherPreferencesStoreTests {
	@Test
	func updateTogglesDefaultToConfiguredValues() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		#expect(store.automaticLauncherUpdates())
		#expect(store.automaticGameUpdates())
		#expect(store.announcementsEnabled())
		#expect(store.showsGameVersion())
		#expect(store.playsLauncherMusic())
		#expect(!store.showsPlayingMusic())
	}

	@Test
	func updateTogglesPersistDisabledValues() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		store.setAutomaticLauncherUpdates(false)
		store.setAutomaticGameUpdates(false)
		store.setAnnouncementsEnabled(false)
		store.setShowsGameVersion(false)
		store.setPlaysLauncherMusic(false)
		store.setShowsPlayingMusic(false)

		#expect(!store.automaticLauncherUpdates())
		#expect(!store.automaticGameUpdates())
		#expect(!store.announcementsEnabled())
		#expect(!store.showsGameVersion())
		#expect(!store.playsLauncherMusic())
		#expect(!store.showsPlayingMusic())
	}

	@Test
	func popupHistoryPersistsAndCapsAnnouncementIDs() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		for index in 0..<110 {
			store.markAnnouncementSeen("message-\(index)")
		}
		store.markLauncherUpdatePresented("0.2.0")

		#expect(store.seenAnnouncementIDs().count == 100)
		#expect(store.presentedLauncherUpdate() == "0.2.0")
	}

	@Test
	func launchOptionsRoundTrip() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		let expected = GameLaunchOptions(displayMode: .borderlessWindow, resolution: .quadHD)

		store.setLaunchOptions(expected)

		#expect(store.launchOptions() == expected)
	}

	@Test
	func installDirectoryRoundTrips() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		let expected = URL(filePath: "/tmp/Arknights Client", directoryHint: .isDirectory)
		let fallback = URL(filePath: "/tmp/Fallback", directoryHint: .isDirectory)

		store.setInstallDirectory(expected, for: .global)

		#expect(store.installDirectory(for: .global, default: fallback) == expected)
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
	func musicURLRoundTrip() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		store.setLauncherMusicURL("https://youtube.com/playlist?list=123")
		#expect(store.launcherMusicURL() == "https://youtube.com/playlist?list=123")
	}

	@Test
	func musicVolumeRoundTrip() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		#expect(store.launcherMusicVolume() == 0.5)

		store.setLauncherMusicVolume(0.8)
		#expect(store.launcherMusicVolume() == 0.8)
	}

	@Test
	func usesDynamicThemeDefaultsToEnabledAndPersists() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		#expect(store.usesDynamicTheme())

		store.setUsesDynamicTheme(false)

		#expect(!store.usesDynamicTheme())
	}

	@Test
	func selectedRegionDefaultsToGlobalAndPersists() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		#expect(store.selectedRegion() == .global)

		store.setSelectedRegion(.korea)

		#expect(store.selectedRegion() == .korea)
	}

	private func makeDefaults() -> (UserDefaults, String) {
		let suiteName = "LauncherPreferencesStoreTests.\(UUID().uuidString)"
		return (UserDefaults(suiteName: suiteName)!, suiteName)
	}
}
