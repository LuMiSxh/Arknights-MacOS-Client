// SPDX-License-Identifier: MPL-2.0

#if DEBUG
	import Foundation

	/// Developer-preview actions. They change only `DeveloperSimulationState`, so a preview
	/// never starts a download, refresh, game process, or system change.
	@MainActor
	struct SimulatedLauncherActions: LauncherActions {
		unowned let model: LauncherViewModel

		private var simulation: DeveloperSimulationState? { model.developerSimulation }

		private var isMigratingStorage: Bool {
			model.lifecycle.activity == .maintaining(.migratingStorage)
		}

		var canRequestDockLaunch: Bool {
			model.lifecycle.activity == .idle && !model.lifecycle.refresh.isChecking
		}

		// MARK: - Region

		func selectRegion(_ newRegion: GameRegion) {
			model.updateDeveloperSimulation { simulation in
				if simulation.selectableRegions.contains(newRegion) {
					simulation.selectedRegion = newRegion
				}
			}
		}

		// MARK: - Installation

		func installOrUpdate() {
			startSimulatedInstallation()
		}

		func repairGame() {
			startSimulatedInstallation()
		}

		private func startSimulatedInstallation() {
			model.updateDeveloperSimulation {
				$0.failure = .none
				$0.lifecycle = .installing
				$0.hasPartialDownload = false
				$0.updateAvailable = true
			}
		}

		func cancelDownload() {
			model.updateDeveloperSimulation {
				$0.failure = .none
				$0.lifecycle = .paused
				$0.hasPartialDownload = true
			}
		}

		// MARK: - Update and announcement checks

		func checkGameUpdates() {
			guard !isMigratingStorage else { return }
			model.updateDeveloperSimulation {
				$0.failure = .none
				$0.lifecycle = .ready
				$0.updateAvailable = true
			}
		}

		func checkLauncherUpdates() {
			guard !isMigratingStorage else { return }
			model.updateDeveloperSimulation {
				$0.failure = .none
				$0.launcherUpdate = .available
			}
		}

		func checkAnnouncements() {
			guard !isMigratingStorage else { return }
			model.updateDeveloperSimulation { $0.popup = .announcement }
		}

		func launcherUpdateCheckForOnboarding() async -> LauncherUpdateCheckOutcome {
			switch simulation?.launcherUpdate {
			case .current, .none: return .current
			case .available: return .updateAvailable("0.6.1")
			case .failed: return .failed
			}
		}

		func openLauncherUpdate() {
			guard let simulation else { return }
			model.communication.presentDeveloperLauncherUpdate(
				version: simulation.launcherUpdate == .available ? "0.6.1" : nil,
				failed: simulation.launcherUpdate == .failed
			)
		}

		func refreshIntelTranslationForUI(force: Bool) async -> IntelTranslationState {
			if let simulation {
				model.applyDeveloperTranslationCheck(simulation)
			}
			return model.intelTranslation.state
		}

		// MARK: - Launching and stopping

		func launch() {
			guard model.gameSession.canLaunch,
				model.lifecycle.failure?.blocksGameLaunch != true
			else { return }
			model.updateDeveloperSimulation {
				$0.failure = .none
				$0.lifecycle = .launching
			}
		}

		/// A simulation never presents the ACE warning, so there is nothing to confirm.
		func confirmACEWarningAndLaunch() {}

		func cancelACEWarning() {}

		func stopGame() {
			model.updateDeveloperSimulation {
				$0.failure = .none
				$0.lifecycle = .ready
			}
		}

		func stopGameForApplicationTermination() {}

		func launchFromDock(region: GameRegion) async -> Bool {
			guard var simulation,
				canRequestDockLaunch,
				model.intelTranslation.allowsWine,
				simulation.selectableRegions.contains(region),
				simulation.installedRegions.contains(region),
				simulation.isInstalled,
				!simulation.hasPartialDownload,
				!simulation.updateAvailable,
				model.lifecycle.failure?.blocksGameLaunch != true
			else { return false }
			simulation.selectedRegion = region
			simulation.failure = .none
			simulation.lifecycle = .running
			model.applyDeveloperSimulation(simulation)
			return true
		}

		// MARK: - Files and settings

		func chooseInstallDirectory() {}

		func locateExistingInstallation() {}

		func resetAllLauncherSettings() {
			guard model.lifecycle.activity == .idle,
				model.settings.resetToDefaults(
					canModifyLaunchOptions: !model.gameSession.isGameActive)
			else {
				return
			}
			model.log.info("Launcher settings reset to default")
		}

		func uninstallGame() {}

		func resetArtwork() {}

		// MARK: - Rosetta

		func installRosetta() async -> IntelTranslationState {
			guard simulation?.rosettaMissing == true else {
				return await refreshIntelTranslationForUI(force: false)
			}
			model.lifecycle.rosettaInstallationState = .installing
			await Task.yield()
			model.lifecycle.rosettaInstallationState = .idle
			model.lifecycle.intelTranslationState = .available
			model.updateDeveloperSimulation { $0.rosettaMissing = false }
			return .available
		}
	}
#endif
