// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import ArknightsGameInstallation
import ArknightsGameRuntime
import ArknightsInfrastructure
import ArknightsPresence
import Foundation
import Observation

@MainActor
@Observable
package final class LauncherViewModel {
	package let lifecycle: LauncherLifecycleStore
	package let settings: LauncherPreferencesController
	package let installation: InstallationController
	package let runtimeSelection: RuntimeSelectionController
	let gameSession: GameSessionController
	let environmentRefresh: GameEnvironmentRefreshController
	package let intelTranslation: IntelTranslationController
	let customization: CustomizationController
	package let communication: LauncherCommunicationController
	let refreshController: LauncherRefreshController
	let storage: StorageMaintenanceController
	let storageOverview: StorageOverviewController
	let playtimeStatistics: PlaytimeStatisticsController
	let discordPresence: DiscordPresenceController
	let reminders: ResetReminderController
	package let screenshots: GameScreenshotController

	let presetCatalog: PresetCatalogService
	package let preferences: LauncherPreferencesStore
	let log: LauncherLog
	package let launcherIconManager: LauncherIconManager
	#if DEBUG
		let api: any LauncherAPIProviding
	#endif

	#if DEBUG
		package var developerAccessibilityMusicTitle: String?
		var developerSimulation: DeveloperSimulationState?
	#endif
	var pendingACEWarningRegion: GameRegion?
	package internal(set) var isSavingDiagnostics = false
	/// True after the pre-0.6 data deletion finishes, so the view can start setup.
	package internal(set) var legacyDataDeletionCompleted = false
	let paths: AppPaths
	/// The single owner of `runtime-selection.json`; every writer shares it.
	let selectionStore: RuntimeSelectionStore
	@ObservationIgnored var startupTask: Task<Bool, Never>?
	@ObservationIgnored var startupOptions = StartupOptions()
	@ObservationIgnored var storageMigrationFailureID: UUID?
	/// Set by the app composition to the sheet-aware quit path.
	@ObservationIgnored package var requestApplicationQuit: @MainActor () -> Void = {}
	@ObservationIgnored var legacyDataDeletionTask: Task<Void, Never>?

	@ObservationIgnored let runtimeInstallSlot = TaskSlot()

	/// True when no activity and no refresh is in flight. Shared by the real and simulated actions.
	package var canRequestDockLaunch: Bool {
		lifecycle.activity == .idle && !lifecycle.state.refresh.isChecking
	}

	/// True while a storage migration owns the launcher; checks and downloads wait.
	var isMigratingStorage: Bool {
		lifecycle.activity == .maintaining(.migratingStorage)
	}
	init(
		api: any LauncherAPIProviding = LauncherAPI(),
		installer: (any GameInstalling)? = nil,
		paths: AppPaths = AppPaths(),
		artworkCache: ArtworkCache? = nil,
		preferences: LauncherPreferencesStore,
		announcementService: LauncherAnnouncementService = LauncherAnnouncementService(),
		launcherIconManager: LauncherIconManager? = nil,
		presetCatalog: PresetCatalogService? = nil,
		gameCompatibilityManager: GameCompatibilityManager? = nil,
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
		self.paths = paths
		#if DEBUG
			self.api = api
		#endif

		let launcherLog = LauncherLog(fileURL: paths.launcherLogFile)
		log = launcherLog
		StartupTimeline.shared.attach(
			launcherLog,
			enabled: preferences.value(LauncherPreferencesStore.Key.debugLoggingEnabled)
		)
		let playtimeStatistics = PlaytimeStatisticsController(
			fileURL: paths.playtimeStatistics,
			log: launcherLog
		)
		self.playtimeStatistics = playtimeStatistics
		let lifecycle = LauncherLifecycleStore(log: launcherLog)
		self.lifecycle = lifecycle
		let selectionStore = RuntimeSelectionStore(
			fileURL: paths.runtimeSelectionFile, log: launcherLog)
		self.selectionStore = selectionStore
		let runtimeSelection = RuntimeSelectionController(
			paths: paths,
			selectionStore: selectionStore,
			lifecycle: lifecycle,
			log: launcherLog
		)
		self.runtimeSelection = runtimeSelection
		let settings = LauncherPreferencesController(store: preferences, log: launcherLog)
		self.settings = settings
		let iconManager = launcherIconManager ?? LauncherIconManager()
		self.launcherIconManager = iconManager
		let catalog =
			presetCatalog
			?? PresetCatalogService(cacheDirectory: paths.presetGalleryCache, log: launcherLog)
		self.presetCatalog = catalog
		let resolvedCompatibilityManager =
			gameCompatibilityManager ?? GameCompatibilityManager(log: launcherLog)
		let resolvedArtworkCache = artworkCache ?? ArtworkCache(directory: paths.artworkCache)
		let gameInstaller =
			installer
			?? GameInstaller(
				api: api,
				compatibilityManager: resolvedCompatibilityManager,
				log: launcherLog,
				reuseSourceDirectories: { [preferences] region in
					await MainActor.run {
						GameRegion.allCases
							.filter { $0 != region }
							.map {
								preferences.installDirectory(
									for: $0, default: paths.gameInstall(for: $0))
							}
					}
				}
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
			runtimeLane: { [weak runtimeSelection] in
				runtimeSelection?.selectedLane ?? paths.runtimeLane
			},
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
			lifecycle: lifecycle,
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
			clearGalleryCache: { try await catalog.clearCaches() },
			log: launcherLog,
			regionProvider: { [weak installation] in installation?.region ?? .global },
			laneProvider: { [weak runtimeSelection] in
				runtimeSelection?.selectedLane ?? paths.runtimeLane
			}
		)
		self.storage = storage
		let storageOverview = StorageOverviewController(
			lifecycle: lifecycle,
			paths: paths,
			preferences: preferences,
			log: launcherLog,
			regionProvider: { [weak installation] in installation?.region ?? .global }
		)
		self.storageOverview = storageOverview
		let gameSession = GameSessionController(
			lifecycle: lifecycle,
			installation: installation,
			settings: settings,
			intelTranslation: intelTranslation,
			paths: paths,
			log: launcherLog,
			gameCompatibilityManager: resolvedCompatibilityManager,
			playtimeStatistics: playtimeStatistics,
			graphicsDiagnosticsEnabled: arguments.contains("--graphics-diagnostics"),
			runtimeLane: { [weak runtimeSelection] in
				runtimeSelection?.selectedLane ?? paths.runtimeLane
			}
		)
		self.gameSession = gameSession
		environmentRefresh = GameEnvironmentRefreshController(
			lifecycle: lifecycle,
			paths: paths,
			compatibilityManager: resolvedCompatibilityManager,
			lane: { [weak runtimeSelection] in
				runtimeSelection?.selectedLane ?? paths.runtimeLane
			},
			installedRegions: { [weak installation] in installation?.installedRegions ?? [] },
			gameDirectory: { [preferences] region in
				preferences.installDirectory(for: region, default: paths.gameInstall(for: region))
			},
			isLaunchPendingOrActive: { [weak gameSession] in
				gameSession?.isLaunchPendingOrActive ?? false
			},
			log: launcherLog
		)
		runtimeSelection.isLaunchInProgress = { [weak gameSession] in
			gameSession?.isLaunchPendingOrActive ?? false
		}
		discordPresence = DiscordPresenceController(
			lifecycle: lifecycle,
			preferences: settings,
			log: launcherLog,
			region: { [weak installation] in installation?.region ?? .global }
		)

		let notificationScheduler = makeNotificationScheduler()
		let reminders = ResetReminderController(
			scheduler: notificationScheduler,
			settings: settings,
			installedRegions: { [weak installation] in installation?.installedRegions ?? [] },
			selectedRegion: { [weak installation] in installation?.region ?? .global },
			log: launcherLog
		)
		self.reminders = reminders
		screenshots = GameScreenshotController(
			lifecycle: lifecycle,
			settings: settings,
			paths: paths,
			scheduler: notificationScheduler,
			region: { [weak gameSession, weak installation] in
				gameSession?.activeGameRegion ?? installation?.region ?? .global
			},
			log: launcherLog
		)

		wireCallbacks()

		#if DEBUG
			developerSimulation =
				DeveloperSimulationState.isPreviewArgument(arguments)
				? DeveloperSimulationState()
				: nil
			if let developerSimulation {
				applyDeveloperSimulation(developerSimulation)
				Task { [weak self] in
					guard let self else { return }
					_ = await customization.loadCustomAppIcon()
					await loadDeveloperArtwork()
					customization.markInitialArtworkLoadComplete()
				}
				log.info("Developer simulation started")
				return
			}
		#endif

		startupOptions = StartupOptions(arguments: arguments)
		beginStartup()
		reminders.start()
		screenshots.start()

		let appVersion = Bundle.main.shortVersionString ?? "Development"
		log.info("Launcher \(appVersion) started")
	}

	deinit {
		startupTask?.cancel()
	}

	func waitForStartup() async -> Bool {
		await startupTask?.value ?? true
	}
}
