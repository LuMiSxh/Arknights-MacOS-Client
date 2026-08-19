// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Observation
import SwiftUI

enum DirectWineProcessExitAction: Equatable {
	case ignore
	case startupFailure
	case gameExited
}

/// The launcher's single source of truth: install/update/launch state, user preferences, and
/// every action the UI can trigger. Behavior is split across `LauncherViewModel+*` extension
/// files by concern (installation, game launch, files, updates, popups) to keep this
/// declaration itself to properties, init, and cross-cutting state.
@MainActor
@Observable
final class LauncherViewModel {
	var phase: LauncherPhase = .checking
	var configuration: GameConfiguration?
	var progress: DownloadProgress?
	var runtimeName: String?
	var branding: LauncherBranding?
	var heroArtwork: NSImage? {
		didSet { updateThemeColor() }
	}
	var officialLogo: NSImage?
	var popup: LauncherPopup?
	var isInstalled = false
	var hasPartialDownload = false
	var installedVersion: String?
	var isGameUpdateAvailable = false
	var launcherUpdate: LauncherRelease?
	var launcherUpdateStatus: String?
	var isCheckingLauncherUpdates = false
	var activityMessage = "Checking…"
	#if DEBUG
		var developerScenario: DeveloperScenario?
	#endif

	private(set) var region: GameRegion
	var installDirectory: URL
	var launchOptions: GameLaunchOptions {
		didSet { preferences.setLaunchOptions(launchOptions) }
	}
	var automaticallyChecksLauncherUpdates: Bool {
		didSet {
			preferences.setAutomaticLauncherUpdates(automaticallyChecksLauncherUpdates)
			if automaticallyChecksLauncherUpdates { checkLauncherUpdates() }
		}
	}
	var automaticallyChecksGameUpdates: Bool {
		didSet {
			preferences.setAutomaticGameUpdates(automaticallyChecksGameUpdates)
			if automaticallyChecksGameUpdates { checkGameUpdates() }
		}
	}
	var announcementsEnabled: Bool {
		didSet {
			preferences.setAnnouncementsEnabled(announcementsEnabled)
			if announcementsEnabled { checkAnnouncements() }
		}
	}
	var showsServerResetCountdown: Bool {
		didSet {
			preferences.setShowsServerResetCountdown(showsServerResetCountdown)
			showsServerResetCountdown ? startResetCountdownTimer() : stopResetCountdownTimer()
		}
	}
	var resetCountdownText: String?
	var showsGameVersion: Bool {
		didSet { preferences.setShowsGameVersion(showsGameVersion) }
	}
	var playsLauncherMusic: Bool {
		didSet { preferences.setPlaysLauncherMusic(playsLauncherMusic) }
	}
	var launcherMusicURL: String {
		didSet { preferences.setLauncherMusicURL(launcherMusicURL) }
	}
	var showsPlayingMusic: Bool {
		didSet { preferences.setShowsPlayingMusic(showsPlayingMusic) }
	}
	var launcherMusicVolume: Double {
		didSet { preferences.setLauncherMusicVolume(launcherMusicVolume) }
	}
	var currentMusicTitle: String?
	var usesDynamicTheme: Bool {
		didSet {
			preferences.setUsesDynamicTheme(usesDynamicTheme)
			updateThemeColor()
		}
	}
	var accentColor: Color = SettingsVisuals.cyan
	var hudTintColor: Color = SettingsVisuals.hudGlassTint

	let api: any LauncherAPIProviding
	let installer: any GameInstalling
	let artworkCache: ArtworkCache
	let updateChecker: LauncherUpdateChecker
	let announcementService: LauncherAnnouncementService
	let paths: AppPaths
	let preferences: LauncherPreferencesStore
	let log: LauncherLog
	let graphicsDiagnosticsEnabled: Bool
	// @Observable's accessor synthesis breaks deinit's access to MainActor-isolated stored
	// properties, so the task handles cancelled there stay plain storage via
	// @ObservationIgnored; every other var below is left tracked since computed properties
	// views read (isGameActive, canStopGame, ...) depend on it.
	@ObservationIgnored var refreshTask: Task<Void, Never>?
	@ObservationIgnored var installationTask: Task<Void, Never>?
	@ObservationIgnored var launchTask: Task<Void, Never>?
	@ObservationIgnored var gameMonitorTask: Task<Void, Never>?
	@ObservationIgnored var gameProcessMonitorTask: Task<Void, Never>?
	@ObservationIgnored var launcherUpdateTask: Task<Void, Never>?
	@ObservationIgnored var announcementTask: Task<Void, Never>?
	@ObservationIgnored var resetCountdownTask: Task<Void, Never>?
	var pendingPopups: [LauncherPopup] = []
	var activeRefreshID: UUID?
	var activeGameSessionID: UUID?
	var gameRunningSince: Date?
	var presentedNoticeContent: String?
	var isStoppingGame = false
	var installationGate = ExclusiveOperationGate()

	init(
		api: any LauncherAPIProviding = LauncherAPI(),
		installer: (any GameInstalling)? = nil,
		paths: AppPaths = AppPaths(),
		preferences: LauncherPreferencesStore = LauncherPreferencesStore(),
		updateChecker: LauncherUpdateChecker = LauncherUpdateChecker(),
		announcementService: LauncherAnnouncementService = LauncherAnnouncementService(),
		arguments: [String] = ProcessInfo.processInfo.arguments
	) {
		self.api = api
		self.paths = paths
		self.preferences = preferences
		graphicsDiagnosticsEnabled = arguments.contains("--graphics-diagnostics")
		self.updateChecker = updateChecker
		self.announcementService = announcementService
		log = LauncherLog(fileURL: paths.launcherLogFile)
		self.installer = installer ?? GameInstaller(api: api, log: log)
		artworkCache = ArtworkCache(directory: paths.artworkCache)
		let selectedRegion = preferences.selectedRegion()
		region = selectedRegion
		installDirectory = preferences.installDirectory(
			for: selectedRegion,
			default: paths.gameInstall(for: selectedRegion)
		)
		launchOptions = preferences.launchOptions()
		automaticallyChecksLauncherUpdates = preferences.automaticLauncherUpdates()
		automaticallyChecksGameUpdates = preferences.automaticGameUpdates()
		announcementsEnabled = preferences.announcementsEnabled()
		showsServerResetCountdown = preferences.showsServerResetCountdown()
		showsGameVersion = preferences.showsGameVersion()
		playsLauncherMusic = preferences.playsLauncherMusic()
		launcherMusicURL = preferences.launcherMusicURL()
		showsPlayingMusic = preferences.showsPlayingMusic()
		launcherMusicVolume = preferences.launcherMusicVolume()
		usesDynamicTheme = preferences.usesDynamicTheme()
		loadCustomAppIcon()
		if showsServerResetCountdown { startResetCountdownTimer() }
		updateThemeColor()

		#if DEBUG
			developerScenario = DeveloperScenario(arguments: arguments)
			if let developerScenario {
				applyDeveloperScenario(developerScenario)
				refreshTask = Task { [weak self] in await self?.loadDeveloperArtwork() }
				Task { [log] in await log.info("Developer simulation started") }
				return
			}
		#endif

		refreshRuntime()
		let installOnLaunch =
			arguments.contains("--install") || arguments.contains("--install-and-launch")
		let launchAfterInstall = arguments.contains("--install-and-launch")
		let launchOnStart = arguments.contains("--launch")

		refreshTask = Task { [weak self] in
			guard let self else { return }
			await refresh()
			if launchOnStart {
				launch()
			} else if installOnLaunch {
				startInstallation(launchAfterCompletion: launchAfterInstall)
			}
		}
		if automaticallyChecksLauncherUpdates {
			checkLauncherUpdates()
		}
		if announcementsEnabled {
			checkAnnouncements()
		}

		let appVersion = Bundle.main.shortVersionString ?? "Development"
		Task { [log] in
			await log.info("Launcher \(appVersion) started")
		}
	}

	deinit {
		refreshTask?.cancel()
		installationTask?.cancel()
		launchTask?.cancel()
		gameMonitorTask?.cancel()
		gameProcessMonitorTask?.cancel()
		launcherUpdateTask?.cancel()
		announcementTask?.cancel()
		resetCountdownTask?.cancel()
	}

	var versionText: String {
		configuration?.gameLatestVersion ?? installedVersion ?? "—"
	}

	var installSizeText: String {
		configuration?.decompressionSize ?? "—"
	}

	var isDownloading: Bool {
		phase == .downloading
	}

	var canInstall: Bool {
		configuration != nil && !isDownloading
	}

	var canLaunch: Bool {
		isInstalled && runtimeName != nil && !isDownloading && !isGameActive
	}

	var isGameRunning: Bool {
		isGameActive
	}

	var canStopGame: Bool {
		Self.canStopGame(
			for: phase,
			hasActiveSession: isGameActive,
			isStoppingGame: isStoppingGame
		)
	}

	static func canStopGame(
		for phase: LauncherPhase,
		hasActiveSession: Bool,
		isStoppingGame: Bool
	) -> Bool {
		guard hasActiveSession, !isStoppingGame else { return false }
		if case .running = phase { return true }
		return false
	}

	static func directWineProcessExitAction(
		for status: Int32,
		phase: LauncherPhase,
		hasActiveSession: Bool
	) -> DirectWineProcessExitAction {
		guard hasActiveSession else { return .ignore }
		if case .launching = phase { return .startupFailure }
		if case .running = phase { return .gameExited }
		return .ignore
	}

	var isGameActive: Bool {
		activeGameSessionID != nil
	}

	var isDeveloperMode: Bool {
		#if DEBUG
			developerScenario != nil
		#else
			false
		#endif
	}

	var canSwitchRegion: Bool {
		!isDownloading && !isGameActive
	}

	func selectRegion(_ newRegion: GameRegion) {
		guard newRegion != region, canSwitchRegion else { return }
		region = newRegion
		preferences.setSelectedRegion(newRegion)
		activeRefreshID = nil
		refreshTask?.cancel()
		configuration = nil
		branding = nil
		heroArtwork = nil
		officialLogo = nil
		isInstalled = false
		hasPartialDownload = false
		installedVersion = nil
		isGameUpdateAvailable = false
		progress = nil
		presentedNoticeContent = nil
		installDirectory = preferences.installDirectory(
			for: newRegion,
			default: paths.gameInstall(for: newRegion)
		)
		phase = .checking
		activityMessage = "Checking…"
		Task { [log] in await log.info("Region switched to \(newRegion.displayName)") }
		refreshTask = Task { [weak self] in await self?.refresh() }
	}

	func refresh(forceGameUpdateCheck: Bool = false) async {
		guard !isDownloading else { return }
		await log.info("Refreshing game and branding state")
		let refreshID = UUID()
		let region = region
		activeRefreshID = refreshID
		updateInstalledState()
		phase = .checking
		activityMessage = "Checking…"
		let hasCustomArtwork = loadCustomArtwork()
		let brandingTask = Task { [api] in try? await api.branding(region: region) }
		defer { brandingTask.cancel() }

		if !isInstalled || automaticallyChecksGameUpdates || forceGameUpdateCheck {
			do {
				let fetchedConfiguration = try await api.gameConfiguration(region: region)
				guard isCurrentRefresh(refreshID) else { return }
				configuration = fetchedConfiguration
				updateGameAvailability()
				await log.info(
					"Game configuration loaded; latest=\(fetchedConfiguration.gameLatestVersion)"
				)
			} catch is CancellationError {
				return
			} catch {
				await log.error("Game configuration failed: \(error.localizedDescription)")
				guard isCurrentRefresh(refreshID) else { return }
				if !isInstalled {
					activeRefreshID = nil
					show(error)
					return
				}
			}
		}

		let fetchedBranding = await brandingTask.value
		guard isCurrentRefresh(refreshID) else { return }
		if let currentBranding = fetchedBranding {
			branding = currentBranding
			presentNoticeIfNeeded(currentBranding)
			await log.info(
				"Branding loaded; noticeEnabled=\(currentBranding.noticePopOpen == true)"
			)
			let logoTask = Task { [artworkCache] in
				guard currentBranding.launcherBackgroundImage != nil else { return nil as Data? }
				return try? await artworkCache.officialLogoData()
			}
			let artworkTask = Task { [artworkCache] in
				guard !hasCustomArtwork else { return nil as Data? }
				return try? await artworkCache.imageData(for: currentBranding)
			}
			let (logoData, artworkData) = await (logoTask.value, artworkTask.value)
			guard isCurrentRefresh(refreshID) else { return }
			if let logoData { officialLogo = NSImage(data: logoData) }
			if let artworkData { heroArtwork = NSImage(data: artworkData) }
		}

		guard isCurrentRefresh(refreshID) else { return }
		activeRefreshID = nil
		phase = .ready
		activityMessage =
			isGameUpdateAvailable
			? "Update available"
			: (isInstalled ? "Ready" : (hasPartialDownload ? "Paused" : "Install"))
		await log.info("Refresh completed; state=\(activityMessage)")
	}

}
