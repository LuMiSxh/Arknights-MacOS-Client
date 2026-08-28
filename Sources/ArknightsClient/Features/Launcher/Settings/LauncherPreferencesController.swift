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
		didSet {
			store.setShowsServerResetCountdown(showsServerResetCountdown)
			showsServerResetCountdown ? startResetCountdownTimer() : stopResetCountdownTimer()
		}
	}
	var resetCountdownText: String?
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
	var appLanguage: AppLanguage {
		didSet {
			store.setAppLanguage(appLanguage)
			L10n.useAppLanguage(appLanguage)
			refreshResetCountdown()
		}
	}
	@ObservationIgnored var onLauncherUpdateCheckRequested: (() -> Void)?
	@ObservationIgnored var onGameUpdateCheckRequested: (() -> Void)?
	@ObservationIgnored var onAnnouncementCheckRequested: (() -> Void)?
	@ObservationIgnored var onDynamicThemeChanged: (() -> Void)?
	@ObservationIgnored var regionProvider: () -> GameRegion = { .global }

	private let store: LauncherPreferencesStore
	@ObservationIgnored private var resetCountdownTask: Task<Void, Never>?

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
		appLanguage = store.appLanguage()
		L10n.useAppLanguage(appLanguage)
	}

	deinit {
		resetCountdownTask?.cancel()
	}

	func start() {
		if showsServerResetCountdown { startResetCountdownTimer() }
	}

	func regionDidChange() {
		refreshResetCountdown()
	}

	/// Keeps region and installation locations intact because they point to user files.
	func resetToDefaults(canModifyLaunchOptions: Bool) -> Bool {
		guard canModifyLaunchOptions else { return false }
		automaticallyChecksLauncherUpdates = true
		automaticallyChecksGameUpdates = true
		announcementsEnabled = true
		launchOptions = .default
		showsServerResetCountdown = false
		showsGameVersion = true
		playsLauncherMusic = true
		launcherMusicURL = AppConstants.Music.defaultLauncherMusicURL
		showsPlayingMusic = false
		launcherMusicVolume = 0.5
		usesDynamicTheme = true
		appLanguage = .system
		return true
	}

	private func startResetCountdownTimer() {
		resetCountdownTask?.cancel()
		refreshResetCountdown()
		resetCountdownTask = Task { [weak self] in
			while !Task.isCancelled {
				try? await Task.sleep(for: .seconds(30))
				guard !Task.isCancelled, let self else { return }
				refreshResetCountdown()
			}
		}
	}

	private func stopResetCountdownTimer() {
		resetCountdownTask?.cancel()
		resetCountdownTask = nil
		resetCountdownText = nil
	}

	private func refreshResetCountdown() {
		guard showsServerResetCountdown else { return }
		resetCountdownText = ServerReset.countdownText(for: regionProvider())
	}
}
