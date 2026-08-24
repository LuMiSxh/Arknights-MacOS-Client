// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

/// Composes feature-owned launcher controllers and coordinates application startup.
@MainActor
@Observable
final class LauncherViewModel {
	let lifecycle: LauncherLifecycleStore
	let settings: LauncherPreferencesController
	let installation: InstallationController
	let gameSession: GameSessionController
	let intelTranslation: IntelTranslationController
	let customization: CustomizationController
	let communication: LauncherCommunicationController
	let refreshController: LauncherRefreshController
	let storage: StorageMaintenanceController

	let presetCatalog: PresetCatalogService
	let preferences: LauncherPreferencesStore
	let log: LauncherLog
	let launcherIconManager: LauncherIconManager
	#if DEBUG
		let api: any LauncherAPIProviding
	#endif

	var currentMusicTitle: String?
	var currentMusicVideoID: String?
	@ObservationIgnored private var startupTask: Task<Void, Never>?
	#if DEBUG
		var developerScenario: DeveloperScenario?
	#endif

	init(
		api: any LauncherAPIProviding = LauncherAPI(),
		installer: (any GameInstalling)? = nil,
		paths: AppPaths = AppPaths(),
		artworkCache: ArtworkCache? = nil,
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
		self.preferences = preferences
		#if DEBUG
			self.api = api
		#endif

		let launcherLog = LauncherLog(fileURL: paths.launcherLogFile)
		log = launcherLog
		let lifecycle = LauncherLifecycleStore(log: launcherLog)
		self.lifecycle = lifecycle
		let settings = LauncherPreferencesController(store: preferences)
		self.settings = settings
		let iconManager = launcherIconManager ?? LauncherIconManager()
		self.launcherIconManager = iconManager
		let catalog =
			presetCatalog
			?? PresetCatalogService(cacheDirectory: paths.presetGalleryCache, log: launcherLog)
		self.presetCatalog = catalog
		let resolvedArtworkCache = artworkCache ?? ArtworkCache(directory: paths.artworkCache)
		let gameInstaller =
			installer
			?? GameInstaller(
				api: api,
				compatibilityManager: gameCompatibilityManager,
				log: launcherLog
			)
		let installation = InstallationController(
			lifecycle: lifecycle,
			installer: gameInstaller,
			paths: paths,
			preferences: preferences,
			log: launcherLog
		)
		self.installation = installation
		let intelTranslation = IntelTranslationController(
			lifecycle: lifecycle,
			checkIntelTranslation: checkIntelTranslation,
			installRosettaSystemSoftware: installRosettaSystemSoftware,
			log: launcherLog
		)
		self.intelTranslation = intelTranslation
		let customization = CustomizationController(
			lifecycle: lifecycle,
			paths: paths,
			preferences: preferences,
			log: launcherLog,
			artworkCache: resolvedArtworkCache,
			launcherIconManager: iconManager,
			region: { [weak installation] in installation?.region ?? .global },
			usesDynamicTheme: { [weak settings] in settings?.usesDynamicTheme ?? true }
		)
		self.customization = customization
		let communication = LauncherCommunicationController(
			updateChecker: updateChecker,
			announcementService: announcementService,
			preferences: preferences,
			log: launcherLog
		)
		self.communication = communication
		let refreshController = LauncherRefreshController(
			lifecycle: lifecycle,
			installation: installation,
			customization: customization,
			communication: communication,
			settings: settings,
			api: api,
			log: launcherLog
		)
		self.refreshController = refreshController
		let storage = StorageMaintenanceController(
			lifecycle: lifecycle,
			paths: paths,
			presetCatalog: catalog,
			log: launcherLog
		)
		self.storage = storage
		let gameSession = GameSessionController(
			lifecycle: lifecycle,
			installation: installation,
			settings: settings,
			intelTranslation: intelTranslation,
			paths: paths,
			preferences: preferences,
			log: launcherLog,
			gameCompatibilityManager: gameCompatibilityManager,
			graphicsDiagnosticsEnabled: arguments.contains("--graphics-diagnostics")
		)
		self.gameSession = gameSession

		settings.regionProvider = { [weak installation] in installation?.region ?? .global }
		settings.onLauncherUpdateCheckRequested = { [weak self] in
			self?.checkLauncherUpdates()
		}
		settings.onGameUpdateCheckRequested = { [weak self] in
			self?.checkGameUpdates()
		}
		settings.onAnnouncementCheckRequested = { [weak self] in
			self?.checkAnnouncements()
		}
		settings.onDynamicThemeChanged = { [weak customization] in
			customization?.updateThemeColor()
		}
		installation.onMetadataRefreshCancellationRequested = { [weak refreshController] in
			refreshController?.cancelForInstallationStart()
		}
		installation.onLaunchRequested = { [weak gameSession] in gameSession?.launch() }
		gameSession.customGameIconURL = { [weak customization, paths] in
			customization?.hasCustomGameIcon == true ? paths.customGameIcon : nil
		}

		customization.restoreInitialArtwork(for: installation.region)
		settings.start()
		customization.updateThemeColor()

		#if DEBUG
			developerScenario = DeveloperScenario(arguments: arguments)
			if let developerScenario {
				applyDeveloperScenario(developerScenario)
				Task { [weak self] in
					guard let self else { return }
					_ = await customization.loadCustomAppIcon()
					await loadDeveloperArtwork()
				}
				Task { [log] in await log.info("Developer simulation started") }
				return
			}
		#endif

		gameSession.refreshRuntime()
		let installOnLaunch =
			arguments.contains("--install") || arguments.contains("--install-and-launch")
		let launchAfterInstall = arguments.contains("--install-and-launch")
		let launchOnStart = arguments.contains("--launch")
		startupTask = Task {
			_ = await customization.loadCustomAppIcon()
			_ = await intelTranslation.refreshAvailability()
			let refreshTask = refreshController.startRefresh()
			await refreshTask.value
			if launchOnStart {
				gameSession.launch()
			} else if installOnLaunch {
				installation.startInstallation(
					launchAfterCompletion: launchAfterInstall)
			}
		}
		if settings.automaticallyChecksLauncherUpdates {
			communication.checkLauncherUpdates()
		}
		if settings.announcementsEnabled {
			communication.checkAnnouncements(isEnabled: true)
		}

		let appVersion = Bundle.main.shortVersionString ?? "Development"
		Task { [log] in await log.info("Launcher \(appVersion) started") }
		storage.refreshSizes()
	}

	deinit {
		startupTask?.cancel()
	}

	func waitForStartup() async {
		await startupTask?.value
	}
}
