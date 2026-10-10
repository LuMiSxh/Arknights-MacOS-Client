// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

/// Owns persisted launcher preferences that are shared across feature controllers.
@MainActor
@Observable
package final class LauncherPreferencesController {
	package var launchOptions: GameLaunchOptions {
		didSet { store.setLaunchOptions(launchOptions) }
	}
	package var automaticallyChecksLauncherUpdates: Bool {
		didSet {
			store.setAutomaticLauncherUpdates(automaticallyChecksLauncherUpdates)
			if automaticallyChecksLauncherUpdates { onLauncherUpdateCheckRequested?() }
		}
	}
	package var automaticallyChecksGameUpdates: Bool {
		didSet {
			store.setAutomaticGameUpdates(automaticallyChecksGameUpdates)
			if automaticallyChecksGameUpdates { onGameUpdateCheckRequested?() }
		}
	}
	package var announcementsEnabled: Bool {
		didSet {
			store.setAnnouncementsEnabled(announcementsEnabled)
			if announcementsEnabled { onAnnouncementCheckRequested?() }
		}
	}
	package var showsServerResetCountdown: Bool {
		didSet { store.setShowsServerResetCountdown(showsServerResetCountdown) }
	}
	package var showsGameVersion: Bool {
		didSet { store.setShowsGameVersion(showsGameVersion) }
	}
	package var playsLauncherMusic: Bool {
		didSet { store.setPlaysLauncherMusic(playsLauncherMusic) }
	}
	package var launcherMusicURL: String {
		didSet { store.setLauncherMusicURL(launcherMusicURL) }
	}
	package var showsPlayingMusic: Bool {
		didSet { store.setShowsPlayingMusic(showsPlayingMusic) }
	}
	package var launcherMusicVolume: Double {
		didSet { store.setLauncherMusicVolume(launcherMusicVolume) }
	}
	package var usesDynamicTheme: Bool {
		didSet {
			store.setUsesDynamicTheme(usesDynamicTheme)
			onDynamicThemeChanged?()
		}
	}
	package var canaryFeaturesEnabled: Bool {
		didSet {
			store.setCanaryFeaturesEnabled(canaryFeaturesEnabled)
			onCanaryFeaturesChanged?(canaryFeaturesEnabled)
		}
	}
	package var taiwanClientEnabled: Bool {
		didSet {
			store.setTaiwanClientEnabled(taiwanClientEnabled)
			onTaiwanClientChanged?(taiwanClientEnabled)
		}
	}
	package var usesHardwareCursor: Bool {
		didSet { store.setUsesHardwareCursor(usesHardwareCursor) }
	}
	/// Hides the one-time explanation of in-game resolutions on Retina displays.
	package var dismissedInGameResolutionNote: Bool {
		didSet { store.setDismissedInGameResolutionNote(dismissedInGameResolutionNote) }
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

	private let store: LauncherPreferencesStore

	package init(store: LauncherPreferencesStore) {
		self.store = store
		launchOptions = store.launchOptions()
		automaticallyChecksLauncherUpdates = store.automaticLauncherUpdates()
		automaticallyChecksGameUpdates = store.automaticGameUpdates()
		announcementsEnabled = store.announcementsEnabled()
		showsServerResetCountdown = store.showsServerResetCountdown()
		showsGameVersion = store.showsGameVersion()
		playsLauncherMusic = store.playsLauncherMusic()
		launcherMusicURL = store.launcherMusicURL()
		showsPlayingMusic = store.showsPlayingMusic()
		launcherMusicVolume = store.launcherMusicVolume()
		usesDynamicTheme = store.usesDynamicTheme()
		canaryFeaturesEnabled = store.canaryFeaturesEnabled()
		taiwanClientEnabled = store.taiwanClientEnabled()
		usesHardwareCursor = store.usesHardwareCursor()
		dismissedInGameResolutionNote = store.dismissedInGameResolutionNote()
	}

	/// Keeps region and installation locations intact because they point to user files.
	package func resetToDefaults(canModifyLaunchOptions: Bool) -> Bool {
		guard canModifyLaunchOptions else { return false }
		store.removeResettablePreferences()
		// Reassigning from the store runs each property's change handlers with the defaults.
		automaticallyChecksLauncherUpdates = store.automaticLauncherUpdates()
		automaticallyChecksGameUpdates = store.automaticGameUpdates()
		announcementsEnabled = store.announcementsEnabled()
		launchOptions = store.launchOptions()
		showsServerResetCountdown = store.showsServerResetCountdown()
		showsGameVersion = store.showsGameVersion()
		playsLauncherMusic = store.playsLauncherMusic()
		launcherMusicURL = store.launcherMusicURL()
		showsPlayingMusic = store.showsPlayingMusic()
		launcherMusicVolume = store.launcherMusicVolume()
		usesDynamicTheme = store.usesDynamicTheme()
		canaryFeaturesEnabled = store.canaryFeaturesEnabled()
		taiwanClientEnabled = store.taiwanClientEnabled()
		usesHardwareCursor = store.usesHardwareCursor()
		dismissedInGameResolutionNote = store.dismissedInGameResolutionNote()
		return true
	}
}
