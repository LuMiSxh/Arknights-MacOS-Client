// SPDX-License-Identifier: MPL-2.0

import ArknightsCore

#if DEBUG
	import Foundation

	// Developer-preview actions. They change only `DeveloperSimulationState`, so a preview
	// never starts a download, refresh, game process, or system change.
	@MainActor
	struct SimulatedLauncherActions: LauncherActions {
		unowned let model: LauncherViewModel

		private var simulation: DeveloperSimulationState? { model.developerSimulation }

		private var isMigratingStorage: Bool {
			model.lifecycle.activity == .maintaining(.migratingStorage)
		}

		var canRequestDockLaunch: Bool {
			model.lifecycle.activity == .idle && !model.lifecycle.state.refresh.isChecking
		}

		/// A preview never writes to disk.
		func saveDiagnostics() async {}

		func selectRegion(_ newRegion: GameRegion) {
			model.updateDeveloperSimulation { simulation in
				if simulation.selectableRegions.contains(newRegion) {
					simulation.selectedRegion = newRegion
				}
			}
		}

		func installOrUpdate() { repairGame() }

		func repairGame() {
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
			model.updateDeveloperSimulation { $0.announcement = true }
		}

		func launcherUpdateCheckForOnboarding() async -> LauncherUpdateCheckOutcome {
			switch simulation?.launcherUpdate {
			case .current, .none: .current
			case .available: .updateAvailable(DeveloperSimulationState.launcherUpdateVersion)
			case .failed: .failed
			}
		}

		// Shows the real update dialog with a fixture instead of starting Sparkle.
		func openLauncherUpdate() {
			let driver = model.communication.launcherUpdateUserDriver
			let dismiss: () -> Void = { [weak driver] in driver?.dismissUpdateInstallation() }
			switch simulation?.launcherUpdate {
			case .failed:
				driver.showUpdaterError(
					NSError(domain: "Developer", code: 1), acknowledgement: dismiss)
			case .available:
				driver.dismissUpdateInstallation()
				driver.version = DeveloperSimulationState.launcherUpdateVersion
				driver.phase = .available
				driver.pendingReply = .choice { [weak driver] choice in
					guard choice == .install else { return }
					driver?.showReady { _ in dismiss() }
				}
			case .current, .none:
				driver.showUpdateNotFoundWithError(
					NSError(domain: "Developer", code: 1), acknowledgement: dismiss)
				driver.message = nil
			}
		}

		func refreshIntelTranslationForUI(force: Bool) async -> IntelTranslationState {
			if let simulation {
				model.applyDeveloperTranslationCheck(simulation)
			}
			return model.intelTranslation.state
		}

		func launch() {
			guard model.gameSession.canLaunch,
				model.lifecycle.state.presentation.failure?.blocksGameLaunch != true
			else { return }
			model.updateDeveloperSimulation {
				$0.failure = .none
				$0.lifecycle = .launching
			}
		}

		// A simulation never presents the ACE warning, so there is nothing to confirm.
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
				model.lifecycle.state.presentation.failure?.blocksGameLaunch != true
			else { return false }
			simulation.selectedRegion = region
			simulation.failure = .none
			simulation.lifecycle = .running
			model.applyDeveloperSimulation(simulation)
			return true
		}

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

		func installRosetta() async -> IntelTranslationState {
			guard simulation?.rosettaMissing == true else {
				return await refreshIntelTranslationForUI(force: false)
			}
			model.lifecycle.state.readiness.rosettaInstallation = .installing
			await Task.yield()
			model.lifecycle.state.readiness.rosettaInstallation = .idle
			model.lifecycle.state.readiness.intelTranslation = .available
			model.updateDeveloperSimulation { $0.rosettaMissing = false }
			return .available
		}
	}
#endif
