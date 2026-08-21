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
	var state = LauncherState()
	var configuration: GameConfiguration? {
		get { state.readiness.configuration }
		set { state.readiness.configuration = newValue }
	}
	var progress: DownloadProgress?
	var runtimeName: String? {
		get { state.readiness.runtimeName }
		set { state.readiness.runtimeName = newValue }
	}
	var branding: LauncherBranding?
	var heroArtwork: NSImage? {
		didSet { updateThemeColor() }
	}
	var officialLogo: NSImage?
	var popup: LauncherPopup?
	var isInstalled: Bool {
		get { state.readiness.isInstalled }
		set { state.readiness.isInstalled = newValue }
	}
	var hasPartialDownload: Bool {
		get { state.readiness.hasPartialDownload }
		set { state.readiness.hasPartialDownload = newValue }
	}
	var installedVersion: String? {
		get { state.readiness.installedVersion }
		set { state.readiness.installedVersion = newValue }
	}
	var isGameUpdateAvailable: Bool {
		get { state.readiness.isGameUpdateAvailable }
		set { state.readiness.isGameUpdateAvailable = newValue }
	}
	var launcherUpdate: LauncherRelease?
	var launcherUpdateStatus: String?
	var isCheckingLauncherUpdates = false
	var activityMessage: String { state.presentation.status.message }
	var failureMessage: String? { state.presentation.failureMessage }
	var intelTranslationState: IntelTranslationState {
		get { state.readiness.intelTranslation }
		set { state.readiness.intelTranslation = newValue }
	}
	var rosettaInstallationState: RosettaInstallationState {
		get { state.readiness.rosettaInstallation }
		set { state.readiness.rosettaInstallation = newValue }
	}
	#if DEBUG
		var developerScenario: DeveloperScenario?
	#endif

	var region: GameRegion
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
	var cacheSizeText = "Calculating…"
	var presetGalleryCacheSizeText = "Calculating…"
	var showsPlayingMusic: Bool {
		didSet { preferences.setShowsPlayingMusic(showsPlayingMusic) }
	}
	var launcherMusicVolume: Double {
		didSet { preferences.setLauncherMusicVolume(launcherMusicVolume) }
	}
	var currentMusicTitle: String?
	var currentMusicVideoID: String?
	var usesDynamicTheme: Bool {
		didSet {
			preferences.setUsesDynamicTheme(usesDynamicTheme)
			updateThemeColor()
		}
	}
	var dynamicThemeHue: Double?
	var accentColor: Color = LauncherVisuals.cyan
	var accentTextColor: Color = Color.black.opacity(0.92)
	var hudTintColor: Color = LauncherVisuals.hudGlassTint

	var appVersion: String { IssueReportURL.appVersion }

	let api: any LauncherAPIProviding
	let installer: any GameInstalling
	let artworkCache: ArtworkCache
	let presetCatalog: PresetCatalogService
	let updateChecker: LauncherUpdateChecker
	let announcementService: LauncherAnnouncementService
	let paths: AppPaths
	let preferences: LauncherPreferencesStore
	let log: LauncherLog
	let launcherIconManager: LauncherIconManager
	let gameCompatibilityManager: GameCompatibilityManager
	let graphicsDiagnosticsEnabled: Bool
	@ObservationIgnored let checkIntelTranslation: @Sendable () async -> IntelTranslationCheck
	@ObservationIgnored let installRosettaSystemSoftware:
		@Sendable () async throws -> IntelTranslationProcessResult
	// @Observable's accessor synthesis breaks deinit's access to MainActor-isolated stored
	// properties, so the task handles cancelled there stay plain storage via
	// @ObservationIgnored; every other var below is left tracked since computed properties
	// views read (isGameActive, canStopGame, ...) depend on it.
	@ObservationIgnored var refreshTask: Task<Void, Never>?
	@ObservationIgnored var installationTask: Task<Void, Never>?
	@ObservationIgnored var launchTask: Task<Void, Never>?
	@ObservationIgnored var gameMonitorTask: Task<Void, Never>?
	@ObservationIgnored var gameProcessMonitorTask: Task<Void, Never>?
	@ObservationIgnored var launcherUpdateTask: Task<LauncherUpdateCheckOutcome, Never>?
	@ObservationIgnored var announcementTask: Task<Void, Never>?
	@ObservationIgnored var resetCountdownTask: Task<Void, Never>?
	@ObservationIgnored var intelTranslationCheckTask: Task<IntelTranslationCheck, Never>?
	@ObservationIgnored var rosettaInstallationTask: Task<IntelTranslationProcessResult, any Error>?
	@ObservationIgnored var activeThemeCacheKey: String?
	var pendingPopups: [LauncherPopup] = []
	var gameRunningSince: Date?
	var presentedNoticeContent: String?
	var installationGate = ExclusiveOperationGate()

	init(
		api: any LauncherAPIProviding = LauncherAPI(),
		installer: (any GameInstalling)? = nil,
		paths: AppPaths = AppPaths(),
		preferences: LauncherPreferencesStore = LauncherPreferencesStore(),
		updateChecker: LauncherUpdateChecker = LauncherUpdateChecker(),
		announcementService: LauncherAnnouncementService = LauncherAnnouncementService(),
		launcherIconManager: LauncherIconManager? = nil,
		presetCatalog: PresetCatalogService? = nil,
		gameCompatibilityManager: GameCompatibilityManager = GameCompatibilityManager(),
		checkIntelTranslation: @escaping @Sendable () async -> IntelTranslationCheck = {
			await RosettaAvailability.check()
		},
		installRosettaSystemSoftware:
			@escaping @Sendable () async throws
			-> IntelTranslationProcessResult = {
				try await RosettaInstaller.install()
			},
		arguments: [String] = ProcessInfo.processInfo.arguments
	) {
		self.api = api
		self.paths = paths
		self.preferences = preferences
		graphicsDiagnosticsEnabled = arguments.contains("--graphics-diagnostics")
		self.updateChecker = updateChecker
		self.announcementService = announcementService
		self.launcherIconManager = launcherIconManager ?? LauncherIconManager()
		self.gameCompatibilityManager = gameCompatibilityManager
		self.checkIntelTranslation = checkIntelTranslation
		self.installRosettaSystemSoftware = installRosettaSystemSoftware
		let launcherLog = LauncherLog(fileURL: paths.launcherLogFile)
		log = launcherLog
		self.presetCatalog =
			presetCatalog
			?? PresetCatalogService(
				cacheDirectory: paths.presetGalleryCache,
				log: launcherLog
			)
		self.installer =
			installer
			?? GameInstaller(
				api: api,
				compatibilityManager: gameCompatibilityManager,
				log: launcherLog
			)
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
		restoreInitialArtwork(for: selectedRegion)
		if showsServerResetCountdown { startResetCountdownTimer() }
		updateThemeColor()

		#if DEBUG
			developerScenario = DeveloperScenario(arguments: arguments)
			if let developerScenario {
				applyDeveloperScenario(developerScenario)
				refreshTask = Task { [weak self] in
					guard let self else { return }
					_ = await loadCustomAppIcon()
					await loadDeveloperArtwork()
				}
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
			_ = await loadCustomAppIcon()
			await refreshIntelTranslationAvailability()
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
		refreshGameCacheSize()
		refreshPresetGalleryCacheSize()
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
		intelTranslationCheckTask?.cancel()
		rosettaInstallationTask?.cancel()
	}

}
