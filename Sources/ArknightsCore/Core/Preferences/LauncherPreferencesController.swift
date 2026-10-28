// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

@MainActor
@Observable
package final class LauncherPreferencesController {
	package var launchOptions: GameLaunchOptions {
		didSet { store.setLaunchOptions(launchOptions) }
	}
	package var automaticallyChecksLauncherUpdates: Bool {
		didSet {
			store.set(automaticallyChecksLauncherUpdates, for: Key.automaticLauncherUpdates)
			if automaticallyChecksLauncherUpdates { onLauncherUpdateCheckRequested?() }
		}
	}
	package var automaticallyChecksGameUpdates: Bool {
		didSet {
			store.set(automaticallyChecksGameUpdates, for: Key.automaticGameUpdates)
			if automaticallyChecksGameUpdates { onGameUpdateCheckRequested?() }
		}
	}
	package var announcementsEnabled: Bool {
		didSet {
			store.set(announcementsEnabled, for: Key.announcementsEnabled)
			if announcementsEnabled { onAnnouncementCheckRequested?() }
		}
	}
	package var showsServerResetCountdown: Bool {
		didSet { store.set(showsServerResetCountdown, for: Key.showsServerResetCountdown) }
	}
	package var showsGameVersion: Bool {
		didSet { store.set(showsGameVersion, for: Key.showsGameVersion) }
	}
	package var showsBranding: Bool {
		didSet { store.set(showsBranding, for: Key.showsBranding) }
	}
	package var playsLauncherMusic: Bool {
		didSet { store.set(playsLauncherMusic, for: Key.playsLauncherMusic) }
	}
	package var launcherMusicURL: String {
		didSet { store.set(launcherMusicURL, for: Key.launcherMusicURL) }
	}
	package var showsPlayingMusic: Bool {
		didSet { store.set(showsPlayingMusic, for: Key.showsPlayingMusic) }
	}
	package var launcherMusicVolume: Double {
		didSet { store.set(launcherMusicVolume, for: Key.launcherMusicVolume) }
	}
	package var launcherMusicMuted: Bool {
		didSet { store.set(launcherMusicMuted, for: Key.launcherMusicMuted) }
	}
	package var usesDynamicTheme: Bool {
		didSet {
			store.set(usesDynamicTheme, for: Key.usesDynamicTheme)
			onDynamicThemeChanged?()
		}
	}
	package var canaryFeaturesEnabled: Bool {
		didSet {
			store.set(canaryFeaturesEnabled, for: Key.canaryFeaturesEnabled)
			onCanaryFeaturesChanged?(canaryFeaturesEnabled)
		}
	}
	package var taiwanClientEnabled: Bool {
		didSet {
			store.set(taiwanClientEnabled, for: Key.taiwanClientEnabled)
			onTaiwanClientChanged?(taiwanClientEnabled)
		}
	}
	package var usesHardwareCursor: Bool {
		didSet { store.set(usesHardwareCursor, for: Key.usesHardwareCursor) }
	}
	package var dismissedInGameResolutionNote: Bool {
		didSet { store.set(dismissedInGameResolutionNote, for: Key.dismissedInGameResolutionNote) }
	}
	package var regionAccess: RegionAccess {
		RegionAccess(
			canaryFeaturesEnabled: canaryFeaturesEnabled,
			taiwanClientEnabled: taiwanClientEnabled
		)
	}
	@ObservationIgnored package var onLauncherUpdateCheckRequested: (() -> Void)?
	@ObservationIgnored package var onGameUpdateCheckRequested: (() -> Void)?
	@ObservationIgnored package var onAnnouncementCheckRequested: (() -> Void)?
	@ObservationIgnored package var onDynamicThemeChanged: (() -> Void)?
	@ObservationIgnored package var onCanaryFeaturesChanged: ((Bool) -> Void)?
	@ObservationIgnored package var onTaiwanClientChanged: ((Bool) -> Void)?

	private typealias Key = LauncherPreferencesStore.Key
	private let store: LauncherPreferencesStore

	package init(store: LauncherPreferencesStore) {
		self.store = store
		launchOptions = store.launchOptions()
		automaticallyChecksLauncherUpdates = store.value(Key.automaticLauncherUpdates)
		automaticallyChecksGameUpdates = store.value(Key.automaticGameUpdates)
		announcementsEnabled = store.value(Key.announcementsEnabled)
		showsServerResetCountdown = store.value(Key.showsServerResetCountdown)
		showsGameVersion = store.value(Key.showsGameVersion)
		showsBranding = store.value(Key.showsBranding)
		playsLauncherMusic = store.value(Key.playsLauncherMusic)
		launcherMusicURL = store.value(Key.launcherMusicURL)
		showsPlayingMusic = store.value(Key.showsPlayingMusic)
		launcherMusicVolume = store.value(Key.launcherMusicVolume)
		launcherMusicMuted = store.value(Key.launcherMusicMuted)
		usesDynamicTheme = store.value(Key.usesDynamicTheme)
		canaryFeaturesEnabled = store.value(Key.canaryFeaturesEnabled)
		taiwanClientEnabled = store.value(Key.taiwanClientEnabled)
		usesHardwareCursor = store.value(Key.usesHardwareCursor)
		dismissedInGameResolutionNote = store.value(Key.dismissedInGameResolutionNote)
	}

	/// Keeps region and installation locations intact because they point to user files.
	package func resetToDefaults(canModifyLaunchOptions: Bool) -> Bool {
		guard canModifyLaunchOptions else { return false }
		store.removeResettablePreferences()
		// Reassigning from the store runs each property's change handlers with the defaults.
		automaticallyChecksLauncherUpdates = store.value(Key.automaticLauncherUpdates)
		automaticallyChecksGameUpdates = store.value(Key.automaticGameUpdates)
		announcementsEnabled = store.value(Key.announcementsEnabled)
		launchOptions = store.launchOptions()
		showsServerResetCountdown = store.value(Key.showsServerResetCountdown)
		showsGameVersion = store.value(Key.showsGameVersion)
		showsBranding = store.value(Key.showsBranding)
		playsLauncherMusic = store.value(Key.playsLauncherMusic)
		launcherMusicURL = store.value(Key.launcherMusicURL)
		showsPlayingMusic = store.value(Key.showsPlayingMusic)
		launcherMusicVolume = store.value(Key.launcherMusicVolume)
		launcherMusicMuted = store.value(Key.launcherMusicMuted)
		usesDynamicTheme = store.value(Key.usesDynamicTheme)
		canaryFeaturesEnabled = store.value(Key.canaryFeaturesEnabled)
		taiwanClientEnabled = store.value(Key.taiwanClientEnabled)
		usesHardwareCursor = store.value(Key.usesHardwareCursor)
		dismissedInGameResolutionNote = store.value(Key.dismissedInGameResolutionNote)
		return true
	}
}
