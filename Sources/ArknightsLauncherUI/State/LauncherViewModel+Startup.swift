// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import Foundation

extension LauncherViewModel {
	/// Composes the launcher with its production services. The application target calls this.
	package convenience init(
		paths: AppPaths,
		preferences: LauncherPreferencesStore,
		arguments: [String]
	) {
		self.init(api: LauncherAPI(), paths: paths, preferences: preferences, arguments: arguments)
	}

	// Launch arguments that shape the startup sequence. A retry after a storage failure reuses them.
	struct StartupOptions: Sendable {
		var installOnLaunch = false
		var launchAfterInstall = false
		var launchOnStart = false

		init() {}

		init(arguments: [String]) {
			launchAfterInstall = arguments.contains("--install-and-launch")
			installOnLaunch = arguments.contains("--install") || launchAfterInstall
			launchOnStart = arguments.contains("--launch")
		}
	}

	// Moving app folders is disk work, so it runs on the concurrent executor.
	@concurrent
	private static func migrateStorage(
		paths: AppPaths,
		selectionStore: RuntimeSelectionStore,
		persistedInstallDirectories: [GameRegion: URL],
		log: LauncherLog
	) async -> LayoutMigrationResult {
		let detector = RunningWineDetector(paths: paths)
		return await LayoutMigrator.migrate(
			paths: paths,
			selectionStore: selectionStore,
			persistedInstallDirectories: persistedInstallDirectories,
			isWineRunning: { await detector.isRunning() },
			log: log
		)
	}

	// Only a storage failure stops the sequence; other startup work runs after migration.
	func beginStartup() {
		let persistedInstallDirectories = preferences.persistedInstallDirectories()
		storageMigrationFailureID = nil
		// Startup runs from idle. Without a lease the migration still runs.
		let activityLease = lifecycle.begin(.maintaining(.migratingStorage))
		lifecycle.setStatus(.migratingStorage)
		// A current layout costs one marker read and a short cleanup, so it runs before the first
		// task turn: the main actor is busy composing the window until then.
		StartupTimeline.shared.beginStep("storage check")
		let currentLayout = LayoutMigrator.migrateCurrentLayout(paths: paths)
		StartupTimeline.shared.endStep("storage check")
		// The migration leaves the artwork cache alone once the layout is current, so the hero and
		// theme restore overlaps the window composition instead of waiting behind the migration.
		var initialArtwork: Task<Void, Never>?
		if let currentLayout, currentLayout.failure == nil {
			initialArtwork = startInitialArtworkRestore()
		}
		startupTask = Task { [paths, selectionStore, log] in
			let migration: LayoutMigrationResult
			if let currentLayout {
				migration = currentLayout
			} else {
				StartupTimeline.shared.beginStep("storage migration")
				migration = await Self.migrateStorage(
					paths: paths,
					selectionStore: selectionStore,
					persistedInstallDirectories: persistedInstallDirectories,
					log: log
				)
				StartupTimeline.shared.endStep("storage migration")
			}
			// Moves that succeeded stay moved, so their preferences must follow even on failure.
			StartupTimeline.shared.beginStep("preferences")
			preferences.updateInstallDirectories(
				migration.installDirectoriesToUpdate,
				replacing: persistedInstallDirectories
			)
			installation.reloadInstallDirectory()
			StartupTimeline.shared.endStep("preferences")
			if let activityLease { lifecycle.end(activityLease) }
			if migration.requiresLegacyDataNotice {
				presentLegacyDataNotice()
				customization.markInitialArtworkLoadComplete()
				return false
			}
			if migration.wineIsRunning {
				presentStorageInUseFailure()
				customization.markInitialArtworkLoadComplete()
				return false
			}
			if let failure = migration.failure {
				presentStorageMigrationFailure(failure)
				customization.markInitialArtworkLoadComplete()
				return false
			}
			StartupTimeline.shared.beginStep("runtime refresh")
			gameSession.refreshRuntime()
			StartupTimeline.shared.endStep("runtime refresh")
			return await runStartupWork(initialArtwork: initialArtwork)
		}
	}

	private func startInitialArtworkRestore() -> Task<Void, Never> {
		StartupTimeline.shared.beginStep("initial artwork")
		let region = installation.region
		return Task { [customization] in
			await customization.restoreInitialArtwork(for: region)
			StartupTimeline.shared.endStep("initial artwork")
		}
	}

	@discardableResult
	func retryStorageMigration(failureID: UUID) -> Bool {
		guard storageMigrationFailureID == failureID,
			lifecycle.state.presentation.failure?.id == failureID,
			lifecycle.canBeginExclusiveActivity,
			lifecycle.consumeFailure(id: failureID) != nil
		else { return false }
		log.info("Recovery selected; action=retry operation=storage-migration")
		beginStartup()
		return true
	}

	/// The pre-0.6 layout cannot be moved without losing data, so startup stops here.
	private func presentLegacyDataNotice() {
		let failure = LauncherFailurePresentation(
			id: UUID(),
			title: "Data from an old launcher version",
			message:
				"This version can't update data from launcher versions older than 0.6. "
				+ "Delete the old data to set up the launcher again.",
			code: nil,
			context: SupportContext(operation: .launcher, region: nil),
			actions: [.deleteDataFolder, .quit],
			blocksGameLaunch: true,
			showsDismissAction: false
		)
		lifecycle.setStatus(.ready, clearsFailure: false)
		lifecycle.presentFailure(
			failure, diagnostic: "Application storage migration: pre-0.6 data layout")
	}

	/// Runs the normal startup sequence after the old data is gone, as on a fresh install.
	func completeStartupAfterLegacyDataDeletion() async -> Bool {
		// The view awaits this task before starting setup; the notice ended the first one.
		startupTask = Task { true }
		gameSession.refreshRuntime()
		let result = await runStartupWork()
		legacyDataDeletionCompleted = true
		return result
	}

	private func presentStorageInUseFailure() {
		let failure = LauncherFailurePresentation(
			id: UUID(),
			title: "Quit the game first",
			message: "The launcher needs to move game data, but a game is still running. "
				+ "Quit the game, then try again.",
			code: nil,
			context: SupportContext(operation: .launcher, region: nil),
			actions: [.tryAgain, .quit],
			blocksGameLaunch: true,
			showsDismissAction: false
		)
		lifecycle.setStatus(.ready, clearsFailure: false)
		storageMigrationFailureID = failure.id
		lifecycle.presentFailure(
			failure, diagnostic: "Application storage migration: a Wine process is still running")
	}

	private func presentStorageMigrationFailure(_ error: any Error) {
		let diagnostic = launcherDiagnosticDescription(for: error)
		let launcherError = LauncherError.storageMigrationFailed(diagnostic)
		let failure = LauncherFailurePresentation(
			id: UUID(),
			message: launcherUserMessage(for: launcherError),
			code: .dataMigrationFailed,
			context: SupportContext(operation: .launcher, region: nil),
			actions: [.retry, .openTroubleshooting, .reportProblem],
			blocksGameLaunch: true
		)
		lifecycle.setStatus(.ready, clearsFailure: false)
		storageMigrationFailureID = failure.id
		lifecycle.presentFailure(
			failure,
			diagnostic: "Application storage migration: \(launcherError.diagnosticDescription)")
	}

	private func runStartupWork(initialArtwork: Task<Void, Never>? = nil) async -> Bool {
		if let initialArtwork {
			await initialArtwork.value
		} else {
			StartupTimeline.shared.beginStep("initial artwork")
			await customization.restoreInitialArtwork(for: installation.region)
			StartupTimeline.shared.endStep("initial artwork")
		}
		customization.markInitialArtworkLoadComplete()

		StartupTimeline.shared.beginStep("custom app icon")
		_ = await customization.loadCustomAppIcon()
		StartupTimeline.shared.endStep("custom app icon")

		StartupTimeline.shared.beginStep("installed state")
		await installation.updateInstalledState().value
		StartupTimeline.shared.endStep("installed state")

		StartupTimeline.shared.beginStep("intel translation")
		_ = await intelTranslation.refreshAvailability()
		StartupTimeline.shared.endStep("intel translation")

		StartupTimeline.shared.beginStep("metadata refresh")
		let refreshTask = refreshController.startRefresh()
		await refreshTask.value
		StartupTimeline.shared.endStep("metadata refresh")

		if settings.automaticallyChecksLauncherUpdates {
			StartupTimeline.shared.beginStep("launcher update probe")
			_ = await communication.checkLauncherUpdates(presentUpdate: true).value
			StartupTimeline.shared.endStep("launcher update probe")
		}
		if settings.announcementsEnabled {
			StartupTimeline.shared.beginStep("announcements")
			communication.checkAnnouncements(isEnabled: true)
			StartupTimeline.shared.endStep("announcements")
		}
		if startupOptions.launchOnStart {
			StartupTimeline.shared.beginStep("launch request")
			gameSession.launch()
			StartupTimeline.shared.endStep("launch request")
		} else if startupOptions.installOnLaunch, installation.canInstall {
			StartupTimeline.shared.beginStep("installation request")
			installation.startInstallation(
				launchAfterCompletion: startupOptions.launchAfterInstall)
			StartupTimeline.shared.endStep("installation request")
		}
		// Prefixes left stale by an earlier runtime update migrate in the background.
		StartupTimeline.shared.beginStep("prefix refresh request")
		environmentRefresh.requestRefresh()
		StartupTimeline.shared.endStep("prefix refresh request")
		StartupTimeline.shared.mark("startup work done")
		return true
	}
}
