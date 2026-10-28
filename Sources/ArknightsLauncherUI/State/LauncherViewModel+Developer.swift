// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import ArknightsGameRuntime

#if DEBUG
	import AppKit
	import Foundation

	extension LauncherViewModel {
		func applyDeveloperSimulation(_ simulation: DeveloperSimulationState) {
			let simulation = simulation.normalized()
			developerSimulation = simulation

			settings.canaryFeaturesEnabled = simulation.canaryFeaturesEnabled
			settings.taiwanClientEnabled = simulation.taiwanClientEnabled
			if installation.region != simulation.selectedRegion {
				lifecycle.simulateActivity(.idle)
				_ = installation.selectRegion(simulation.selectedRegion)
			}
			for region in GameRegion.allCases {
				installation.setRegionInstalled(
					region, simulation.installedRegions.contains(region))
			}

			communication.resetPopupQueueForDeveloper()
			installation.cancelInstalledStateRefresh()
			installation.configuration = Self.developerConfiguration
			installation.progress = simulation.downloadProgress
			installation.isInstalled = simulation.isInstalled
			installation.hasPartialDownload = simulation.hasPartialDownload
			installation.installedVersion = simulation.installedVersion
			installation.isGameUpdateAvailable = simulation.updateAvailable
			gameSession.runtimeName = "Wine 11.16 + DXMT 0.80-199"
			communication.launcherUpdateVersion = simulation.launcherUpdateVersion
			communication.launcherUpdateStatus = simulation.launcherUpdateStatus
			communication.isCheckingLauncherUpdates = false
			lifecycle.state.refresh = .idle
			lifecycle.simulateActivity(simulatedActivity(for: simulation))
			lifecycle.setStatus(simulation.status, clearsFailure: simulation.failure == .none)
			settings.showsServerResetCountdown = simulation.showStatusPill
			settings.showsGameVersion = simulation.showVersionPill
			settings.showsPlayingMusic = simulation.showMusicPill
			settings.usesDynamicTheme = simulation.usesDynamicTheme
			developerAccessibilityMusicTitle =
				simulation.longAccessibilityText
				? "A very long Arknights soundtrack title for keyboard and layout checks"
				: "Developer preview soundtrack"
			applyDeveloperFailure(simulation)
			applyDeveloperTranslationCheck(simulation)
			if simulation.announcement { enqueueDeveloperAnnouncement() }
		}

		func applyDeveloperTranslationCheck(_ simulation: DeveloperSimulationState) {
			intelTranslation.applyAvailabilityCheck(
				IntelTranslationCheck(
					state: simulation.rosettaMissing ? .rosettaMissing : .available,
					diagnostics: "Developer preview"
				)
			)
		}

		func updateDeveloperSimulation(_ update: (inout DeveloperSimulationState) -> Void) {
			guard var simulation = developerSimulation else { return }
			update(&simulation)
			applyDeveloperSimulation(simulation)
		}

		func loadDeveloperArtwork() async {
			let region = installation.region
			guard !region.requiresCanaryPermission else { return }
			if await customization.loadCustomArtwork() { return }
			let artworkCache = customization.artworkCache
			do {
				let currentBranding = try await api.branding(region: region)
				guard isDeveloperMode, installation.region == region else { return }
				refreshController.branding = currentBranding
				do {
					let logoData = try await artworkCache.officialLogoData(for: region)
					guard installation.region == region else { return }
					customization.officialLogo = logoData.flatMap(NSImage.init(data:))
				} catch {
					log.error(
						"Failed to load developer logo: \(error.localizedDescription)"
					)
				}
				do {
					if let imageData = try await artworkCache.imageData(
						for: currentBranding,
						region: region
					), let image = NSImage(data: imageData),
						let artworkCacheKey = artworkCache.cacheKey(for: currentBranding)
					{
						guard installation.region == region else { return }
						customization.setHeroArtwork(
							image,
							themeCacheKey: CustomizationController.officialThemeCacheKey(
								for: region,
								artworkCacheKey: artworkCacheKey
							)
						)
					}
				} catch {
					log.error(
						"Failed to load developer artwork: \(error.localizedDescription)"
					)
				}
			} catch {
				log.error(
					"Failed to load developer branding: \(error.localizedDescription)"
				)
			}
		}

		private func applyDeveloperFailure(_ simulation: DeveloperSimulationState) {
			let region = simulation.selectedRegion
			guard let operation = simulation.failure.operation else {
				if lifecycle.state.presentation.failure?.context.operation
					!= .intelTranslationPreflight
					|| !installation.isInstalled
				{
					lifecycle.clearFailure()
				}
				return
			}
			let code = simulation.failureCode
			let isConfiguration = operation == .configurationRefresh
			let existingFailure = lifecycle.state.presentation.failure
			let isSameFailure =
				existingFailure?.code == code && existingFailure?.context.operation == operation
				&& existingFailure?.context.region == region.supportRegion
			let error: any LauncherDiagnosticError =
				isConfiguration
				? LauncherError.invalidResponse
				: GameRuntimeError.runtimeExited(
					status: 1, log: gameSession.paths.runtimeLogFile(for: region))
			lifecycle.state.presentation.failure = LauncherFailurePresentation(
				id: isSameFailure ? existingFailure?.id ?? UUID() : UUID(),
				message: launcherUserMessage(for: error),
				code: code,
				context: SupportContext(operation: operation, region: region.supportRegion),
				actions: isConfiguration
					? [.retry, .openTroubleshooting, .reportProblem]
					: LauncherLifecycleStore.recoveryActions(
						for: code,
						canRepair: simulation.isInstalled && operation != .runtimeStop),
				blocksGameLaunch: isConfiguration && !simulation.isInstalled
			)
		}

		private func enqueueDeveloperAnnouncement() {
			communication.enqueuePopup(
				LauncherPopup(
					id: "developer-announcement",
					title: "Help improve Arknights Client",
					content: .markdown(
						"Found a bug or have an idea? Share it on GitHub so it can be tracked."
					),
					dismissTitle: "Done",
					actionTitle: "Open GitHub Issues",
					actionURL: URL(
						string: "https://github.com/LuMiSxh/Arknights-MacOS-Client/issues")
				)
			)
		}

		private func simulatedActivity(for simulation: DeveloperSimulationState) -> LauncherActivity
		{
			switch simulation.lifecycle {
			case .ready, .paused: .idle
			case .installing:
				.installing(id: UUID(), stage: simulation.installationStage)
			case .launching:
				.launchingGame(sessionID: UUID(), processIdentifier: nil)
			case .running:
				.runningGame(sessionID: UUID(), processIdentifier: 4242)
			}
		}

		private static let developerConfiguration = GameConfiguration(
			gameLowestVersion: "041.0.0",
			gameLatestVersion: "042.0.0",
			gameLatestFilePath: "client.zip",
			gameStartExeName: "Arknights",
			gameStartParams: [],
			gameUninstallScript: "uninstall.exe",
			decompressionSize: "38 GB"
		)
	}
#endif
