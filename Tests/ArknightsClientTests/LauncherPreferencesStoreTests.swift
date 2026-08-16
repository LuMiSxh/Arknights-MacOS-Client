// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherPreferencesStoreTests {
	@Test
	func updateTogglesDefaultToEnabled() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		#expect(store.automaticLauncherUpdates())
		#expect(store.automaticGameUpdates())
		#expect(store.announcementsEnabled())
	}

	@Test
	func updateTogglesPersistDisabledValues() {
		let (defaults, suiteName) = makeDefaults()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)

		store.setAutomaticLauncherUpdates(false)
		store.setAutomaticGameUpdates(false)
		store.setAnnouncementsEnabled(false)

		#expect(!store.automaticLauncherUpdates())
		#expect(!store.automaticGameUpdates())
		#expect(!store.announcementsEnabled())
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

		store.setInstallDirectory(expected)

		#expect(store.installDirectory(default: fallback) == expected)
	}

	private func makeDefaults() -> (UserDefaults, String) {
		let suiteName = "LauncherPreferencesStoreTests.\(UUID().uuidString)"
		return (UserDefaults(suiteName: suiteName)!, suiteName)
	}
}
