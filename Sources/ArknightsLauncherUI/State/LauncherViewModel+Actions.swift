// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import Foundation

// Production action bodies live here and never branch on developer mode; debug builds
// substitute `SimulatedLauncherActions`.
extension LauncherViewModel: LauncherActions {
	var isDeveloperMode: Bool {
		#if DEBUG
			developerSimulation != nil
		#else
			false
		#endif
	}

	var isOnboardingPreview: Bool {
		#if DEBUG
			developerSimulation?.onboardingPreview == true
		#else
			false
		#endif
	}

	var isRequiredOnboardingPreview: Bool {
		#if DEBUG
			developerSimulation?.onboardingRequired == true
		#else
			false
		#endif
	}

	/// The actions views call. Simulated while a developer simulation runs (debug builds only).
	package var actions: any LauncherActions {
		#if DEBUG
			if developerSimulation != nil { return SimulatedLauncherActions(model: self) }
		#endif
		return self
	}

	static func shouldPresentACEWarning(for region: GameRegion, acknowledged: Bool) -> Bool {
		region.requiresACEWarning && !acknowledged
	}

	package var canRequestDockLaunch: Bool {
		lifecycle.activity == .idle && !lifecycle.state.refresh.isChecking
	}

	private var isMigratingStorage: Bool {
		lifecycle.activity == .maintaining(.migratingStorage)
	}

	// MARK: - Region

	package func selectRegion(_ newRegion: GameRegion) {
		_ = refreshController.selectRegion(newRegion)
	}

	// MARK: - Installation

	package func installOrUpdate() {
		installation.installOrUpdate()
	}

	package func repairGame() {
		installation.repairGame()
	}

	package func cancelDownload() {
		installation.cancelDownload()
	}

	// MARK: - Update and announcement checks

	package func checkGameUpdates() {
		guard !isMigratingStorage else { return }
		refreshController.checkGameUpdates()
	}

	package func checkLauncherUpdates() {
		guard !isMigratingStorage else { return }
		communication.checkLauncherUpdates()
	}

	package func checkAnnouncements() {
		guard !isMigratingStorage else { return }
		communication.checkAnnouncements(isEnabled: settings.announcementsEnabled)
	}

	package func launcherUpdateCheckForOnboarding() async -> LauncherUpdateCheckOutcome {
		guard await waitForStartup() else { return .failed }
		return await communication.launcherUpdateCheckForOnboarding()
	}

	package func openLauncherUpdate() {
		communication.openLauncherUpdate()
	}

	package func refreshIntelTranslationForUI(force: Bool) async -> IntelTranslationState {
		await intelTranslation.refreshAvailability(force: force)
	}

	// MARK: - Launching and stopping

	package func launch() {
		let region = installation.region
		if Self.shouldPresentACEWarning(
			for: region,
			acknowledged: preferences.hasAcknowledgedACEWarning(for: region)
		) {
			pendingACEWarningRegion = region
			return
		}
		gameSession.launch()
	}

	package func confirmACEWarningAndLaunch() {
		guard let region = pendingACEWarningRegion else { return }
		guard installation.region == region, region.requiresACEWarning else {
			pendingACEWarningRegion = nil
			return
		}
		preferences.markACEWarningAcknowledged(for: region)
		pendingACEWarningRegion = nil
		gameSession.launch()
	}

	package func cancelACEWarning() {
		pendingACEWarningRegion = nil
	}

	package func stopGame() {
		gameSession.stopGame()
	}

	package func stopGameForApplicationTermination() {
		gameSession.stopGameForApplicationTermination()
	}

	package func launchFromDock(region: GameRegion) async -> Bool {
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

	package func chooseInstallDirectory() {
		installation.chooseInstallDirectory()
	}

	package func locateExistingInstallation() {
		installation.locateExistingInstallation()
	}

	package func resetAllLauncherSettings() {
		guard lifecycle.activity == .idle,
			settings.resetToDefaults(canModifyLaunchOptions: !gameSession.isGameActive)
		else {
			return
		}
		log.info("Launcher settings reset to default")
	}

	package func uninstallGame() {
		installation.uninstallGame()
	}

	package func resetArtwork() {
		customization.resetArtwork(
			isDownloading: installation.isDownloading,
			restartRefresh: { [weak refreshController] in
				refreshController?.startRefresh()
			}
		)
	}

	// MARK: - Rosetta

	package func installRosetta() async -> IntelTranslationState {
		await intelTranslation.installRosetta()
	}
}
