// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

@MainActor
@Observable
package final class LauncherPreferencesController {
	private let log: LauncherLog?
	package var launchOptions: GameLaunchOptions = .default {
		didSet {
			guard isLoaded else { return }
			do {
				try store.setLaunchOptions(launchOptions)
			} catch {
				log?.error("Could not save game launch options: \(error.localizedDescription)")
			}
		}
	}
	package var automaticallyChecksLauncherUpdates = Key.automaticLauncherUpdates.defaultValue {
		didSet {
			persist(automaticallyChecksLauncherUpdates, for: Key.automaticLauncherUpdates)
			if automaticallyChecksLauncherUpdates { onLauncherUpdateCheckRequested?() }
		}
	}
	package var automaticallyChecksGameUpdates = Key.automaticGameUpdates.defaultValue {
		didSet {
			persist(automaticallyChecksGameUpdates, for: Key.automaticGameUpdates)
			if automaticallyChecksGameUpdates { onGameUpdateCheckRequested?() }
		}
	}
	package var announcementsEnabled = Key.announcementsEnabled.defaultValue {
		didSet {
			persist(announcementsEnabled, for: Key.announcementsEnabled)
			if announcementsEnabled { onAnnouncementCheckRequested?() }
		}
	}
	package var showsServerResetCountdown = Key.showsServerResetCountdown.defaultValue {
		didSet { persist(showsServerResetCountdown, for: Key.showsServerResetCountdown) }
	}
	package var showsGameVersion = Key.showsGameVersion.defaultValue {
		didSet { persist(showsGameVersion, for: Key.showsGameVersion) }
	}
	package var showsBranding = Key.showsBranding.defaultValue {
		didSet { persist(showsBranding, for: Key.showsBranding) }
	}
	package var playsLauncherMusic = Key.playsLauncherMusic.defaultValue {
		didSet { persist(playsLauncherMusic, for: Key.playsLauncherMusic) }
	}
	package var launcherMusicURL = Key.launcherMusicURL.defaultValue {
		didSet { persist(launcherMusicURL, for: Key.launcherMusicURL) }
	}
	package var showsPlayingMusic = Key.showsPlayingMusic.defaultValue {
		didSet { persist(showsPlayingMusic, for: Key.showsPlayingMusic) }
	}
	package var showsDiscordPresence = Key.showsDiscordPresence.defaultValue {
		didSet {
			persist(showsDiscordPresence, for: Key.showsDiscordPresence)
			onDiscordPresenceChanged?()
		}
	}
	package var launcherMusicVolume = Key.launcherMusicVolume.defaultValue {
		didSet { persist(launcherMusicVolume, for: Key.launcherMusicVolume) }
	}
	package var launcherMusicMuted = Key.launcherMusicMuted.defaultValue {
		didSet { persist(launcherMusicMuted, for: Key.launcherMusicMuted) }
	}
	package var usesDynamicTheme = Key.usesDynamicTheme.defaultValue {
		didSet {
			persist(usesDynamicTheme, for: Key.usesDynamicTheme)
			onDynamicThemeChanged?()
		}
	}
	package var launcherAppearance: LauncherAppearance = .system {
		didSet {
			guard isLoaded else { return }
			store.setLauncherAppearance(launcherAppearance)
		}
	}
	package var homeTheme: HomeTheme = .automatic {
		didSet {
			guard isLoaded else { return }
			store.setHomeTheme(homeTheme)
		}
	}
	package var brandingTheme: HomeTheme = .automatic {
		didSet {
			guard isLoaded else { return }
			store.setBrandingTheme(brandingTheme)
		}
	}

	package var resetReminderTiming: ResetReminderTiming = .off {
		didSet {
			guard isLoaded else { return }
			store.setResetReminderTiming(resetReminderTiming)
			onResetReminderChanged?()
		}
	}

	package var resetReminderRegions: [GameRegion] = [] {
		didSet {
			guard isLoaded else { return }
			store.setResetReminderRegions(resetReminderRegions)
			onResetReminderChanged?()
		}
	}
	package var canaryFeaturesEnabled = Key.canaryFeaturesEnabled.defaultValue {
		didSet {
			persist(canaryFeaturesEnabled, for: Key.canaryFeaturesEnabled)
			onCanaryFeaturesChanged?(canaryFeaturesEnabled)
		}
	}
	package var usesHardwareCursor = Key.usesHardwareCursor.defaultValue {
		didSet { persist(usesHardwareCursor, for: Key.usesHardwareCursor) }
	}
	package var dismissedInGameResolutionNote = Key.dismissedInGameResolutionNote.defaultValue {
		didSet { persist(dismissedInGameResolutionNote, for: Key.dismissedInGameResolutionNote) }
	}
	package var batterySaverEnabled = Key.batterySaverEnabled.defaultValue {
		didSet { persist(batterySaverEnabled, for: Key.batterySaverEnabled) }
	}
	package var batterySaverFrameRateLimit: GameFrameRateLimit = .fps30 {
		didSet {
			guard isLoaded else { return }
			store.setBatterySaverFrameRateLimit(batterySaverFrameRateLimit)
		}
	}
	package var screenshotShortcut: ScreenshotShortcut = .off {
		didSet {
			guard isLoaded else { return }
			store.setScreenshotShortcut(screenshotShortcut)
			onScreenshotShortcutChanged?(oldValue)
		}
	}
	package var screenshotNotifies = Key.screenshotNotifies.defaultValue {
		didSet { persist(screenshotNotifies, for: Key.screenshotNotifies) }
	}
	/// The folder the user chose for screenshots, or `nil` for the default folder.
	package var screenshotDirectory: URL? {
		didSet {
			guard isLoaded else { return }
			store.setScreenshotDirectory(screenshotDirectory)
		}
	}
	package var regionAccess: RegionAccess {
		RegionAccess(
			canaryFeaturesEnabled: canaryFeaturesEnabled
		)
	}
	@ObservationIgnored package var onLauncherUpdateCheckRequested: (() -> Void)?
	@ObservationIgnored package var onGameUpdateCheckRequested: (() -> Void)?
	@ObservationIgnored package var onAnnouncementCheckRequested: (() -> Void)?
	@ObservationIgnored package var onDynamicThemeChanged: (() -> Void)?
	@ObservationIgnored package var onCanaryFeaturesChanged: ((Bool) -> Void)?
	@ObservationIgnored package var onDiscordPresenceChanged: (() -> Void)?
	@ObservationIgnored package var onResetReminderChanged: (() -> Void)?
	/// Called with the previous value after the shortcut changes, including a reset to defaults.
	@ObservationIgnored package var onScreenshotShortcutChanged: ((ScreenshotShortcut) -> Void)?

	private typealias Key = LauncherPreferencesStore.Key
	private let store: LauncherPreferencesStore
	// `init` loads without writing defaults back; later changes persist.
	@ObservationIgnored private var isLoaded = false

	package init(store: LauncherPreferencesStore, log: LauncherLog? = nil) {
		self.store = store
		self.log = log
		reload()
		isLoaded = true
	}

	/// Keeps region and installation locations intact because they point to user files.
	package func resetToDefaults(canModifyLaunchOptions: Bool) -> Bool {
		guard canModifyLaunchOptions else { return false }
		store.removeResettablePreferences()
		// Reloading runs each property's change handlers with the defaults.
		reload()
		return true
	}

	/// Reads every preference from the store. `init` and `resetToDefaults` share it, so the
	/// two cannot drift apart.
	private func reload() {
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
		showsDiscordPresence = store.value(Key.showsDiscordPresence)
		launcherMusicVolume = store.value(Key.launcherMusicVolume)
		launcherMusicMuted = store.value(Key.launcherMusicMuted)
		usesDynamicTheme = store.value(Key.usesDynamicTheme)
		canaryFeaturesEnabled = store.value(Key.canaryFeaturesEnabled)
		usesHardwareCursor = store.value(Key.usesHardwareCursor)
		dismissedInGameResolutionNote = store.value(Key.dismissedInGameResolutionNote)
		batterySaverEnabled = store.value(Key.batterySaverEnabled)
		batterySaverFrameRateLimit = store.batterySaverFrameRateLimit()
		screenshotShortcut = store.screenshotShortcut()
		screenshotNotifies = store.value(Key.screenshotNotifies)
		screenshotDirectory = store.screenshotDirectory()
		launcherAppearance = store.launcherAppearance()
		homeTheme = store.homeTheme()
		brandingTheme = store.brandingTheme()
		resetReminderTiming = store.resetReminderTiming()
		resetReminderRegions = store.resetReminderRegions()
	}

	private func persist<Value: Sendable>(
		_ value: Value,
		for key: LauncherPreferencesStore.ScalarKey<Value>
	) {
		guard isLoaded else { return }
		store.set(value, for: key)
	}
}
