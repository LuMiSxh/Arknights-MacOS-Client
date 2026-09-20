// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Every action the launcher UI can trigger. Views call these rather than the controllers,
/// because each one carries policy: developer-preview short-circuits, the ACE warning, and
/// the guards that keep checks from firing during a storage migration.
extension LauncherViewModel {
	// MARK: - Developer-mode state

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

	// MARK: - Region

	func selectRegion(_ newRegion: GameRegion) {
		#if DEBUG
			if isDeveloperMode {
				updateDeveloperSimulation { simulation in
					if simulation.selectableRegions.contains(newRegion) {
						simulation.selectedRegion = newRegion
					}
				}
				return
			}
		#endif
		_ = refreshController.selectRegion(newRegion)
	}

	// MARK: - Installation

	func installOrUpdate() {
		#if DEBUG
			if isDeveloperMode {
				updateDeveloperSimulation {
					$0.failure = .none
					$0.lifecycle = .installing
					$0.hasPartialDownload = false
					$0.updateAvailable = true
				}
				return
			}
		#endif
		installation.installOrUpdate()
	}

	func repairGame() {
		#if DEBUG
			if isDeveloperMode {
				updateDeveloperSimulation {
					$0.failure = .none
					$0.lifecycle = .installing
					$0.hasPartialDownload = false
					$0.updateAvailable = true
				}
				return
			}
		#endif
		installation.repairGame()
	}

	func cancelDownload() {
		#if DEBUG
			if isDeveloperMode {
				updateDeveloperSimulation {
					$0.failure = .none
					$0.lifecycle = .paused
					$0.hasPartialDownload = true
				}
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
				updateDeveloperSimulation {
					$0.failure = .none
					$0.lifecycle = .ready
					$0.updateAvailable = true
				}
				return
			}
		#endif
		refreshController.checkGameUpdates()
	}

	func checkLauncherUpdates() {
		guard lifecycle.activity != .maintaining(.migratingStorage) else { return }
		#if DEBUG
			if isDeveloperMode {
				updateDeveloperSimulation {
					$0.failure = .none
					$0.launcherUpdate = .available
				}
				return
			}
		#endif
		communication.checkLauncherUpdates()
	}

	func checkAnnouncements() {
		guard lifecycle.activity != .maintaining(.migratingStorage) else { return }
		#if DEBUG
			if isDeveloperMode {
				updateDeveloperSimulation { $0.popup = .announcement }
				return
			}
		#endif
		communication.checkAnnouncements(isEnabled: settings.announcementsEnabled)
	}

	func launcherUpdateCheckForOnboarding() async -> LauncherUpdateCheckOutcome {
		#if DEBUG
			if isDeveloperMode {
				switch developerSimulation?.launcherUpdate {
				case .current, .none: return .current
				case .available: return .updateAvailable("0.6.1")
				case .failed: return .failed
				}
			}
		#endif
		guard await waitForStartup() else { return .failed }
		return await communication.launcherUpdateCheckForOnboarding()
	}

	func openLauncherUpdate() {
		#if DEBUG
			if let simulation = developerSimulation {
				communication.presentDeveloperLauncherUpdate(
					version: simulation.launcherUpdate == .available ? "0.6.1" : nil,
					failed: simulation.launcherUpdate == .failed
				)
				return
			}
		#endif
		communication.openLauncherUpdate()
	}

	@discardableResult
	func refreshIntelTranslationForUI(force: Bool = false) async -> IntelTranslationState {
		#if DEBUG
			if let simulation = developerSimulation {
				let state: IntelTranslationState =
					simulation.rosettaMissing
					? .rosettaMissing
					: .available
				lifecycle.intelTranslationState = state
				return state
			}
		#endif
		return await intelTranslation.refreshAvailability(force: force)
	}

	// MARK: - Launching and stopping

	static func shouldPresentACEWarning(for region: GameRegion, acknowledged: Bool) -> Bool {
		region.requiresACEWarning && !acknowledged
	}

	func launch() {
		#if DEBUG
			if isDeveloperMode {
				updateDeveloperSimulation {
					$0.failure = .none
					$0.lifecycle = .launching
				}
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
				updateDeveloperSimulation {
					$0.failure = .none
					$0.lifecycle = .ready
				}
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
		#if DEBUG
			if isDeveloperMode { return simulateDeveloperDockLaunch(region: region) }
		#endif
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

	#if DEBUG
		private func simulateDeveloperDockLaunch(region: GameRegion) -> Bool {
			guard var simulation = developerSimulation,
				canRequestDockLaunch,
				simulation.selectableRegions.contains(region),
				simulation.installedRegions.contains(region),
				simulation.isInstalled,
				!simulation.hasPartialDownload,
				!simulation.updateAvailable,
				simulation.failure == .none
			else { return false }
			simulation.selectedRegion = region
			simulation.lifecycle = .running
			applyDeveloperSimulation(simulation)
			return true
		}
	#endif

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
			if isDeveloperMode {
				if developerSimulation?.rosettaMissing == true {
					lifecycle.rosettaInstallationState = .installing
					await Task.yield()
					lifecycle.rosettaInstallationState = .idle
					lifecycle.intelTranslationState = .available
					updateDeveloperSimulation { $0.rosettaMissing = false }
					return .available
				}
				return await refreshIntelTranslationForUI()
			}
		#endif

		return await intelTranslation.installRosetta()
	}
}
