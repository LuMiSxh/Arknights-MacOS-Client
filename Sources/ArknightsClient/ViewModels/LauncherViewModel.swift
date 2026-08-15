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
	@Published var notice: LauncherNotice?
	@Published var isInstalled = false
	@Published var installedVersion: String?
	@Published var isGameUpdateAvailable = false
	@Published var launcherUpdate: LauncherRelease?
	@Published var launcherUpdateStatus: String?
	@Published var isCheckingLauncherUpdates = false
	@Published var isDownloading = false
	@Published var activityMessage = "Checking…"

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

	let api: any LauncherAPIProviding
	let installer: any GameInstalling
	let artworkCache: ArtworkCache
	let updateChecker: LauncherUpdateChecker
	let paths: AppPaths
	let preferences: LauncherPreferencesStore
	let log: LauncherLog
	var refreshTask: Task<Void, Never>?
	var installationTask: Task<Void, Never>?
	var launchTask: Task<Void, Never>?
	var gameMonitorTask: Task<Void, Never>?
	var gameProcessMonitorTask: Task<Void, Never>?
	var launcherUpdateTask: Task<Void, Never>?
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
		arguments: [String] = ProcessInfo.processInfo.arguments
	) {
		self.api = api
		self.paths = paths
		self.preferences = preferences
		self.updateChecker = updateChecker
		self.installer = installer ?? GameInstaller(api: api)
		log = LauncherLog(fileURL: paths.launcherLogFile)
		artworkCache = ArtworkCache(directory: paths.artworkCache)
		installDirectory = preferences.installDirectory(default: paths.globalGameInstall)
		launchOptions = preferences.launchOptions()
		automaticallyChecksLauncherUpdates = preferences.automaticLauncherUpdates()
		automaticallyChecksGameUpdates = preferences.automaticGameUpdates()

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
	}

	var versionText: String {
		configuration?.gameLatestVersion ?? installedVersion ?? "—"
	}

	var installSizeText: String {
		configuration?.decompressionSize ?? "—"
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

	func refresh(forceGameUpdateCheck: Bool = false) async {
		guard !isDownloading else { return }
		await log.info("Refreshing game and branding state")
		let refreshID = UUID()
		activeRefreshID = refreshID
		updateInstalledState()
		phase = .checking
		activityMessage = "Checking…"
		let hasCustomArtwork = loadCustomArtwork()

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

		let fetchedBranding = try? await api.branding()
		guard isCurrentRefresh(refreshID) else { return }
		if let currentBranding = fetchedBranding {
			branding = currentBranding
			presentNoticeIfNeeded(currentBranding)
			await log.info(
				"Branding loaded; noticeEnabled=\(currentBranding.noticePopOpen == true)"
			)
			if currentBranding.launcherBackgroundImage != nil,
				let data = try? await artworkCache.officialLogoData()
			{
				guard isCurrentRefresh(refreshID) else { return }
				officialLogo = NSImage(data: data)
			}
			if !hasCustomArtwork,
				let data = try? await artworkCache.imageData(for: currentBranding)
			{
				guard isCurrentRefresh(refreshID) else { return }
				heroArtwork = NSImage(data: data)
			}
		}

		guard isCurrentRefresh(refreshID) else { return }
		activeRefreshID = nil
		phase = .ready
		activityMessage =
			isGameUpdateAvailable ? "Update available" : (isInstalled ? "Ready" : "Install")
		await log.info("Refresh completed; state=\(activityMessage)")
	}

	func checkGameUpdates() {
		guard !isDownloading else { return }
		activeRefreshID = nil
		refreshTask?.cancel()
		refreshTask = Task { [weak self] in
			await self?.refresh(forceGameUpdateCheck: true)
		}
	}

	func checkLauncherUpdates() {
		guard !isCheckingLauncherUpdates else { return }
		guard
			let endpointString = Bundle.main.object(forInfoDictionaryKey: "LauncherUpdatesURL")
				as? String,
			let endpoint = URL(string: endpointString)
		else {
			launcherUpdateStatus = "Update source unavailable"
			return
		}

		launcherUpdateTask?.cancel()
		isCheckingLauncherUpdates = true
		launcherUpdateStatus = "Checking…"
		launcherUpdateTask = Task { [weak self] in
			guard let self else { return }
			defer { isCheckingLauncherUpdates = false }
			do {
				guard let release = try await updateChecker.latestRelease(from: endpoint) else {
					launcherUpdate = nil
					launcherUpdateStatus = "No releases available"
					await log.info("Launcher update check completed; no releases available")
					return
				}
				let currentVersion =
					Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
					as? String ?? "0"
				if !release.isDraft && !release.isPrerelease
					&& updateChecker.isNewer(release.version, than: currentVersion)
				{
					launcherUpdate = release
					launcherUpdateStatus = "Version \(release.version) available"
				} else {
					launcherUpdate = nil
					launcherUpdateStatus = "Up to date"
				}
				await log.info(
					"Launcher update check completed; status=\(launcherUpdateStatus ?? "Unknown")"
				)
			} catch is CancellationError {
				launcherUpdateStatus = nil
			} catch {
				launcherUpdateStatus = "Couldn’t check for updates"
				await log.error("Launcher update check failed: \(error.localizedDescription)")
			}
		}
	}

	func openLauncherUpdate() {
		guard let url = launcherUpdate?.htmlURL else { return }
		NSWorkspace.shared.open(url)
	}

}
