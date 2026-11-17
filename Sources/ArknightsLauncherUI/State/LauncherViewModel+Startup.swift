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
		persistedInstallDirectories: [GameRegion: URL],
		log: LauncherLog
	) async -> LayoutMigrationResult {
		let detector = RunningWineDetector(paths: paths)
		return await LayoutMigrator.migrate(
			paths: paths,
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
		startupTask = Task { [paths, log] in
			let migration = await Self.migrateStorage(
				paths: paths,
				persistedInstallDirectories: persistedInstallDirectories,
				log: log
			)
			// Moves that succeeded stay moved, so their preferences must follow even on failure.
			preferences.updateInstallDirectories(
				migration.installDirectoriesToUpdate,
				replacing: persistedInstallDirectories
			)
			installation.reloadInstallDirectory()
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
			gameSession.refreshRuntime()
			return await runStartupWork()
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

	private func runStartupWork() async -> Bool {
		await customization.restoreInitialArtwork(for: installation.region)
		customization.markInitialArtworkLoadComplete()
		_ = await customization.loadCustomAppIcon()
		await installation.updateInstalledState().value
		_ = await intelTranslation.refreshAvailability()
		let refreshTask = refreshController.startRefresh()
		await refreshTask.value
		if settings.automaticallyChecksLauncherUpdates {
			_ = await communication.checkLauncherUpdates(presentUpdate: true).value
		}
		if settings.announcementsEnabled {
			communication.checkAnnouncements(isEnabled: true)
		}
		if startupOptions.launchOnStart {
			gameSession.launch()
		} else if startupOptions.installOnLaunch, installation.canInstall {
			installation.startInstallation(
				launchAfterCompletion: startupOptions.launchAfterInstall)
		}
		// Prefixes left stale by an earlier runtime update migrate in the background.
		environmentRefresh.requestRefresh()
		return true
	}
}
