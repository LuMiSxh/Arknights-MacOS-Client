// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	/// Launch arguments that shape the startup sequence. A retry after a storage failure reuses them.
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

	/// Migrates storage, then runs the normal startup work. Only a storage failure stops the sequence.
	func beginStartup() {
		let persistedInstallDirectories = preferences.persistedInstallDirectories()
		storageMigrationFailureID = nil
		// Startup runs from idle. Without a lease the migration still runs, as before.
		let activityLease = lifecycle.begin(.maintaining(.migratingStorage))
		lifecycle.setStatus(.migratingStorage)
		startupTask = Task { [paths] in
			let migration = await Task.detached(priority: .utility) {
				AppStorageMigrator.migrate(
					paths: paths,
					persistedInstallDirectories: persistedInstallDirectories
				)
			}.value
			// Moves that succeeded stay moved, so their preferences must follow even on failure.
			preferences.updateInstallDirectories(
				migration.installDirectoriesToUpdate,
				replacing: persistedInstallDirectories
			)
			installation.reloadInstallDirectory()
			if let activityLease { lifecycle.end(activityLease) }
			if let failure = migration.failure {
				presentStorageMigrationFailure(failure)
				customization.markInitialArtworkLoadComplete()
				return false
			}
			gameSession.refreshRuntime()
			return await runStartupWork()
		}
	}

	/// Starts the startup sequence again for the recorded failure. The failure must be current and
	/// the launcher must be idle.
	@discardableResult
	func retryStorageMigration(failureID: UUID) -> Bool {
		guard storageMigrationFailureID == failureID,
			lifecycle.failure?.id == failureID,
			lifecycle.canBeginExclusiveActivity,
			lifecycle.consumeFailure(id: failureID) != nil
		else { return false }
		log.info("Recovery selected; action=retry operation=storage-migration")
		beginStartup()
		return true
	}

	private func presentStorageMigrationFailure(_ error: any Error) {
		let diagnostic = launcherDiagnosticDescription(for: error)
		let launcherError = LauncherError.storageMigrationFailed(diagnostic)
		let failure = LauncherFailurePresentation(
			id: UUID(),
			message: launcherUserMessage(for: launcherError),
			code: .basalt,
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
		return true
	}
}
