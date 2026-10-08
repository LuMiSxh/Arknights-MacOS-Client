// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

/// Owns persisted launcher preferences that are shared across feature controllers.
@MainActor
@Observable
final class LauncherPreferencesController {
	var launchOptions: GameLaunchOptions {
		didSet { store.setLaunchOptions(launchOptions) }
	}
	var automaticallyChecksLauncherUpdates: Bool {
		didSet {
			store.setAutomaticLauncherUpdates(automaticallyChecksLauncherUpdates)
			if automaticallyChecksLauncherUpdates { onLauncherUpdateCheckRequested?() }
		}
	}
	var automaticallyChecksGameUpdates: Bool {
		didSet {
			store.setAutomaticGameUpdates(automaticallyChecksGameUpdates)
			if automaticallyChecksGameUpdates { onGameUpdateCheckRequested?() }
		}
	}
	var announcementsEnabled: Bool {
		didSet {
			store.setAnnouncementsEnabled(announcementsEnabled)
			if announcementsEnabled { onAnnouncementCheckRequested?() }
		}
	}
	var showsServerResetCountdown: Bool {
		didSet { store.setShowsServerResetCountdown(showsServerResetCountdown) }
	}
	var showsGameVersion: Bool {
		didSet { store.setShowsGameVersion(showsGameVersion) }
	}
	var playsLauncherMusic: Bool {
		didSet { store.setPlaysLauncherMusic(playsLauncherMusic) }
	}
	var launcherMusicURL: String {
		didSet { store.setLauncherMusicURL(launcherMusicURL) }
	}
	var showsPlayingMusic: Bool {
		didSet { store.setShowsPlayingMusic(showsPlayingMusic) }
	}
	var launcherMusicVolume: Double {
		didSet { store.setLauncherMusicVolume(launcherMusicVolume) }
	}
	var usesDynamicTheme: Bool {
		didSet {
			store.setUsesDynamicTheme(usesDynamicTheme)
			onDynamicThemeChanged?()
		}
	}
	var canaryFeaturesEnabled: Bool {
		didSet {
			store.setCanaryFeaturesEnabled(canaryFeaturesEnabled)
			onCanaryFeaturesChanged?(canaryFeaturesEnabled)
		}
	}
	var taiwanClientEnabled: Bool {
		didSet {
			store.setTaiwanClientEnabled(taiwanClientEnabled)
			onTaiwanClientChanged?(taiwanClientEnabled)
		}
	}
	var usesHardwareCursor: Bool {
		didSet { store.setUsesHardwareCursor(usesHardwareCursor) }
	}
	/// Hides the one-time explanation of in-game resolutions on Retina displays.
	var dismissedInGameResolutionNote: Bool {
		didSet { store.setDismissedInGameResolutionNote(dismissedInGameResolutionNote) }
	}
	var regionAccess: RegionAccess {
		RegionAccess(
			canaryFeaturesEnabled: canaryFeaturesEnabled,
			taiwanClientEnabled: taiwanClientEnabled
		)
	}
	@ObservationIgnored var onLauncherUpdateCheckRequested: (() -> Void)?
	@ObservationIgnored var onGameUpdateCheckRequested: (() -> Void)?
	@ObservationIgnored var onAnnouncementCheckRequested: (() -> Void)?
	@ObservationIgnored var onDynamicThemeChanged: (() -> Void)?
	@ObservationIgnored var onCanaryFeaturesChanged: ((Bool) -> Void)?
	@ObservationIgnored var onTaiwanClientChanged: ((Bool) -> Void)?

	private let store: LauncherPreferencesStore

	init(store: LauncherPreferencesStore) {
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
	func resetToDefaults(canModifyLaunchOptions: Bool) -> Bool {
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
