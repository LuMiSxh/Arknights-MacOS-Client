// SPDX-License-Identifier: MPL-2.0

import AppKit
import Combine
import Foundation

enum DirectWineProcessExitAction: Equatable {
	case ignore
	case startupFailure
	case gameExited
}

@MainActor
final class LauncherViewModel: ObservableObject {
	@Published var phase: LauncherPhase = .checking
	@Published var configuration: GameConfiguration?
	@Published var progress: DownloadProgress?
	@Published var runtimeName: String?
	@Published var branding: LauncherBranding?
	@Published var heroArtwork: NSImage?
	@Published var officialLogo: NSImage?
	@Published var popup: LauncherPopup?
	@Published var isInstalled = false
	@Published var installedVersion: String?
	@Published var isGameUpdateAvailable = false
	@Published var launcherUpdate: LauncherRelease?
	@Published var launcherUpdateStatus: String?
	@Published var isCheckingLauncherUpdates = false
	@Published var activityMessage = "Checking…"
	#if DEBUG
		@Published var developerScenario: DeveloperScenario?
	#endif

	@Published var installDirectory: URL
	@Published var launchOptions: GameLaunchOptions {
		didSet { preferences.setLaunchOptions(launchOptions) }
	}
	@Published var automaticallyChecksLauncherUpdates: Bool {
		didSet {
			preferences.setAutomaticLauncherUpdates(automaticallyChecksLauncherUpdates)
			if automaticallyChecksLauncherUpdates { checkLauncherUpdates() }
		}
	}
	@Published var automaticallyChecksGameUpdates: Bool {
		didSet {
			preferences.setAutomaticGameUpdates(automaticallyChecksGameUpdates)
			if automaticallyChecksGameUpdates { checkGameUpdates() }
		}
	}
	@Published var announcementsEnabled: Bool {
		didSet {
			preferences.setAnnouncementsEnabled(announcementsEnabled)
			if announcementsEnabled { checkAnnouncements() }
		}
	}

	let api: any LauncherAPIProviding
	let installer: any GameInstalling
	let artworkCache: ArtworkCache
	let updateChecker: LauncherUpdateChecker
	let announcementService: LauncherAnnouncementService
	let paths: AppPaths
	let preferences: LauncherPreferencesStore
	let log: LauncherLog
	let graphicsDiagnosticsEnabled: Bool
	var refreshTask: Task<Void, Never>?
	var installationTask: Task<Void, Never>?
	var launchTask: Task<Void, Never>?
	var gameMonitorTask: Task<Void, Never>?
	var gameProcessMonitorTask: Task<Void, Never>?
	var launcherUpdateTask: Task<Void, Never>?
	var announcementTask: Task<Void, Never>?
	var pendingPopups: [LauncherPopup] = []
	var activeRefreshID: UUID?
	var activeGameSessionID: UUID?
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
		self.installer = installer ?? GameInstaller(api: api)
		log = LauncherLog(fileURL: paths.launcherLogFile)
		artworkCache = ArtworkCache(directory: paths.artworkCache)
		installDirectory = preferences.installDirectory(default: paths.globalGameInstall)
		launchOptions = preferences.launchOptions()
		automaticallyChecksLauncherUpdates = preferences.automaticLauncherUpdates()
		automaticallyChecksGameUpdates = preferences.automaticGameUpdates()
		announcementsEnabled = preferences.announcementsEnabled()

		#if DEBUG
			developerScenario = DeveloperScenario(arguments: arguments)
			if let developerScenario {
				applyDeveloperScenario(developerScenario)
				if developerScenario == .customPopup {
					applyDeveloperPopup(arguments: arguments)
				}
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

		let appVersion =
			Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
			?? "Development"
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

	func refresh(forceGameUpdateCheck: Bool = false) async {
		guard !isDownloading else { return }
		await log.info("Refreshing game and branding state")
		let refreshID = UUID()
		activeRefreshID = refreshID
		updateInstalledState()
		phase = .checking
		activityMessage = "Checking…"
		let hasCustomArtwork = loadCustomArtwork()
		let brandingTask = Task { [api] in try? await api.branding() }
		defer { brandingTask.cancel() }

		if !isInstalled || automaticallyChecksGameUpdates || forceGameUpdateCheck {
			do {
				let fetchedConfiguration = try await api.gameConfiguration()
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
			isGameUpdateAvailable ? "Update available" : (isInstalled ? "Ready" : "Install")
		await log.info("Refresh completed; state=\(activityMessage)")
	}

}
