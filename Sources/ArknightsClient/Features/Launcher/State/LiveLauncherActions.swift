// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Production launcher actions. They hold only the controllers they drive and never
/// consult developer-simulation state.
@MainActor
struct LiveLauncherActions: LauncherActions {
	let lifecycle: LauncherLifecycleStore
	let settings: LauncherPreferencesController
	let installation: InstallationController
	let gameSession: GameSessionController
	let intelTranslation: IntelTranslationController
	let customization: CustomizationController
	let communication: LauncherCommunicationController
	let refreshController: LauncherRefreshController
	let preferences: LauncherPreferencesStore
	let log: LauncherLog
	let waitForStartup: () async -> Bool
	let pendingACEWarningRegion: () -> GameRegion?
	let setPendingACEWarningRegion: (GameRegion?) -> Void

	static func shouldPresentACEWarning(for region: GameRegion, acknowledged: Bool) -> Bool {
		region.requiresACEWarning && !acknowledged
	}

	var canRequestDockLaunch: Bool {
		lifecycle.activity == .idle && !lifecycle.refresh.isChecking
	}

	private var isMigratingStorage: Bool {
		lifecycle.activity == .maintaining(.migratingStorage)
	}

	// MARK: - Region

	func selectRegion(_ newRegion: GameRegion) {
		_ = refreshController.selectRegion(newRegion)
	}

	// MARK: - Installation

	func installOrUpdate() {
		installation.installOrUpdate()
	}

	func repairGame() {
		installation.repairGame()
	}

	func cancelDownload() {
		installation.cancelDownload()
	}

	// MARK: - Update and announcement checks

	func checkGameUpdates() {
		guard !isMigratingStorage else { return }
		refreshController.checkGameUpdates()
	}

	func checkLauncherUpdates() {
		guard !isMigratingStorage else { return }
		communication.checkLauncherUpdates()
	}

	func checkAnnouncements() {
		guard !isMigratingStorage else { return }
		communication.checkAnnouncements(isEnabled: settings.announcementsEnabled)
	}

	func launcherUpdateCheckForOnboarding() async -> LauncherUpdateCheckOutcome {
		guard await waitForStartup() else { return .failed }
		return await communication.launcherUpdateCheckForOnboarding()
	}

	func openLauncherUpdate() {
		communication.openLauncherUpdate()
	}

	func refreshIntelTranslationForUI(force: Bool) async -> IntelTranslationState {
		await intelTranslation.refreshAvailability(force: force)
	}

	// MARK: - Launching and stopping

	func launch() {
		let region = installation.region
		if Self.shouldPresentACEWarning(
			for: region,
			acknowledged: preferences.hasAcknowledgedACEWarning(for: region)
		) {
			setPendingACEWarningRegion(region)
			return
		}
		gameSession.launch()
	}

	func confirmACEWarningAndLaunch() {
		guard let region = pendingACEWarningRegion() else { return }
		guard installation.region == region, region.requiresACEWarning else {
			setPendingACEWarningRegion(nil)
			return
		}
		preferences.markACEWarningAcknowledged(for: region)
		setPendingACEWarningRegion(nil)
		gameSession.launch()
	}

	func cancelACEWarning() {
		setPendingACEWarningRegion(nil)
	}

	func stopGame() {
		gameSession.stopGame()
	}

	func stopGameForApplicationTermination() {
		gameSession.stopGameForApplicationTermination()
	}

	func launchFromDock(region: GameRegion) async -> Bool {
		guard canRequestDockLaunch else { return false }
		await installation.updateInstalledState().value
		guard canRequestDockLaunch, installation.isRegionInstalled(region) else { return false }
		if installation.region != region {
			guard refreshController.selectRegion(region) else { return false }
			await refreshController.waitForCurrentRefresh()
		}
		guard
			installation.region == region,
			installation.isInstalled,
			!installation.isGameUpdateAvailable,
			gameSession.canLaunch
		else { return false }
		launch()
		return gameSession.isGameActive
	}

	// MARK: - Files and settings

	func chooseInstallDirectory() {
		installation.chooseInstallDirectory()
	}

	func locateExistingInstallation() {
		installation.locateExistingInstallation()
	}

	func resetAllLauncherSettings() {
		guard lifecycle.activity == .idle,
			settings.resetToDefaults(canModifyLaunchOptions: !gameSession.isGameActive)
		else {
			return
		}
		log.info("Launcher settings reset to default")
	}

	func uninstallGame() {
		installation.uninstallGame()
	}

	func resetArtwork() {
		customization.resetArtwork(
			isDownloading: installation.isDownloading,
			restartRefresh: { [weak refreshController] in
				refreshController?.startRefresh()
			}
		)
	}

	// MARK: - Rosetta

	func installRosetta() async -> IntelTranslationState {
		await intelTranslation.installRosetta()
	}
}
