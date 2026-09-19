// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Every action the launcher UI can trigger. Views call these rather than the controllers,
/// because each one carries policy: developer-scenario short-circuits, the ACE warning, and
/// the guards that keep checks from firing during a storage migration.
extension LauncherViewModel {
	// MARK: - Developer-mode state

	var isDeveloperMode: Bool {
		#if DEBUG
			developerScenario != nil
		#else
			false
		#endif
	}

	var isOnboardingPreview: Bool {
		#if DEBUG
			developerScenario == .onboardingRosetta
		#else
			false
		#endif
	}

	// MARK: - Region

	func selectRegion(_ newRegion: GameRegion) {
		_ = refreshController.selectRegion(newRegion)
	}

	// MARK: - Installation

	func installOrUpdate() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.downloading)
				return
			}
		#endif
		installation.installOrUpdate()
	}

	func repairGame() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.downloading)
				return
			}
		#endif
		installation.repairGame()
	}

	func cancelDownload() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.paused)
				return
			}
		#endif
		installation.cancelDownload()
	}

	// MARK: - Update and announcement checks

	func checkGameUpdates() {
		guard lifecycle.activity != .maintaining(.migratingStorage) else { return }
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.gameUpdate)
				return
			}
		#endif
		refreshController.checkGameUpdates()
	}

	func checkLauncherUpdates() {
		guard lifecycle.activity != .maintaining(.migratingStorage) else { return }
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.launcherUpdate)
				return
			}
		#endif
		communication.checkLauncherUpdates()
	}

	func checkAnnouncements() {
		guard lifecycle.activity != .maintaining(.migratingStorage) else { return }
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.announcement)
				return
			}
		#endif
		communication.checkAnnouncements(isEnabled: settings.announcementsEnabled)
	}

	func launcherUpdateCheckForOnboarding() async -> LauncherUpdateCheckOutcome {
		guard await waitForStartup() else { return .failed }
		#if DEBUG
			if isOnboardingPreview { return .current }
		#endif
		return await communication.launcherUpdateCheckForOnboarding()
	}

	// MARK: - Launching and stopping

	static func shouldPresentACEWarning(for region: GameRegion, acknowledged: Bool) -> Bool {
		region.requiresACEWarning && !acknowledged
	}

	func launch() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.launching)
				return
			}
		#endif
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

	func confirmACEWarningAndLaunch() {
		guard let region = pendingACEWarningRegion else { return }
		guard installation.region == region, region.requiresACEWarning else {
			pendingACEWarningRegion = nil
			return
		}
		preferences.markACEWarningAcknowledged(for: region)
		pendingACEWarningRegion = nil
		gameSession.launch()
	}

	func cancelACEWarning() {
		pendingACEWarningRegion = nil
	}

	func stopGame() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.ready)
				return
			}
		#endif
		gameSession.stopGame()
	}

	func stopGameForApplicationTermination() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		gameSession.stopGameForApplicationTermination()
	}

	// MARK: - Dock launch

	var canRequestDockLaunch: Bool {
		lifecycle.activity == .idle && !lifecycle.refresh.isChecking
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
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		installation.chooseInstallDirectory()
	}

	func locateExistingInstallation() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		installation.locateExistingInstallation()
	}

	func resetAllLauncherSettings() {
		guard lifecycle.activity == .idle,
			settings.resetToDefaults(canModifyLaunchOptions: !gameSession.isGameActive)
		else {
			return
		}
		Task { [log] in await log.info("Launcher settings reset to default") }
	}

	func uninstallGame() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		installation.uninstallGame()
	}

	// MARK: - Artwork

	func resetArtwork() {
		customization.resetArtwork(
			isDeveloperMode: isDeveloperMode,
			isDownloading: installation.isDownloading,
			restartRefresh: { [weak refreshController] in
				refreshController?.startRefresh()
			}
		)
	}

	// MARK: - Rosetta

	@discardableResult
	func installRosetta() async -> IntelTranslationState {
		#if DEBUG
			if developerScenario == .onboardingRosetta {
				lifecycle.rosettaInstallationState = .installing
				await Task.yield()
				lifecycle.rosettaInstallationState = .idle
				lifecycle.intelTranslationState = .available
				return .available
			}
		#endif

		return await intelTranslation.installRosetta()
	}
}
