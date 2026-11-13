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

	/// True when onboarding may auto-start. A developer simulation that is not an onboarding
	/// preview stays out of the way.
	var canStartOnboarding: Bool {
		#if DEBUG
			if isDeveloperMode { return isOnboardingPreview }
		#endif
		return true
	}

	/// True when onboarding must re-read the installed state from disk first. A developer
	/// simulation already holds the simulated state, so a refresh would overwrite it.
	var onboardingShouldRefreshInstalledState: Bool {
		!isDeveloperMode
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

	// MARK: - Runtime

	/// Downloads the pinned runtime for `lane`, selects it, and refreshes discovery and the
	/// Intel translation preflight so the next launch uses it.
	@discardableResult
	package func installRuntime(_ lane: RuntimeLane) async -> Bool {
		let installed = await runtimeSelection.install(lane: lane)
		if installed {
			gameSession.refreshRuntime()
			if runtimeSelection.selectedLane == lane {
				intelTranslation.runtimeLaneDidChange()
				_ = await intelTranslation.refreshAvailability(force: true)
			}
		}
		return installed
	}

	package func pauseRuntimeDownload() {
		runtimeSelection.pauseInstall()
	}

	@discardableResult
	package func selectRuntimeLane(_ lane: RuntimeLane) -> Bool {
		do {
			try runtimeSelection.select(lane: lane)
			gameSession.refreshRuntime()
			intelTranslation.runtimeLaneDidChange()
			Task { [weak self] in
				_ = await self?.intelTranslation.refreshAvailability(force: true)
			}
			return true
		} catch {
			log.error(
				"Runtime lane switch failed: \(launcherDiagnosticDescription(for: error))")
			return false
		}
	}

	@discardableResult
	package func removeOtherRuntime() async -> Bool {
		do {
			try await runtimeSelection.removeOtherLane()
			return true
		} catch {
			log.error(
				"Other runtime removal failed: \(launcherDiagnosticDescription(for: error))")
			return false
		}
	}

	@discardableResult
	package func removeSelectedRuntime() async -> Bool {
		do {
			try await runtimeSelection.removeSelectedLane()
			gameSession.refreshRuntime()
			return true
		} catch {
			log.error(
				"Runtime removal failed: \(launcherDiagnosticDescription(for: error))")
			return false
		}
	}

	/// Starts the Home runtime action. It goes through `actions`, so a developer preview does
	/// not write the runtime selection to disk.
	package func installSelectedRuntime() {
		let lane = runtimeSelection.selectedLane
		runtimeInstallSlot.replace { [weak self] _ in
			guard let self else { return }
			_ = await actions.installRuntime(lane)
		}
	}

	// MARK: - Rosetta

	package func installRosetta() async -> IntelTranslationState {
		await intelTranslation.installRosetta()
	}
}
