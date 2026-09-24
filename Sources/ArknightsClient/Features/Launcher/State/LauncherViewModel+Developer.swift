// SPDX-License-Identifier: MPL-2.0

#if DEBUG
	import AppKit
	import Foundation

	extension LauncherViewModel {
		func applyDeveloperSimulation(_ simulation: DeveloperSimulationState) {
			var simulation = simulation.normalized()
			applyDeveloperRegionState(&simulation)
			developerSimulation = simulation

			communication.resetPopupQueueForDeveloper()
			let projection = simulation.projection()
			installation.cancelInstalledStateRefresh()
			installation.configuration = Self.developerConfiguration
			installation.progress = projection.progress
			installation.isInstalled = projection.isInstalled
			installation.hasPartialDownload = projection.hasPartialDownload
			installation.installedVersion = projection.installedVersion
			installation.isGameUpdateAvailable = projection.isGameUpdateAvailable
			gameSession.runtimeName = "Wine 11.16 + DXMT 0.80-199"
			communication.launcherUpdateVersion = projection.launcherUpdateVersion
			communication.launcherUpdateStatus = projection.launcherUpdateStatus
			communication.isCheckingLauncherUpdates = false
			lifecycle.intelTranslationState =
				simulation.rosettaMissing ? .rosettaMissing : .available
			lifecycle.refresh = .idle
			lifecycle.activity = simulatedActivity(for: simulation)
			lifecycle.setStatus(projection.status, clearsFailure: projection.failureCode == nil)
			applyDeveloperPreferences(simulation)
			applyDeveloperFailure(projection, region: simulation.selectedRegion)
			applyDeveloperPopup(simulation)
		}

		func updateDeveloperSimulation(_ update: (inout DeveloperSimulationState) -> Void) {
			guard var simulation = developerSimulation else { return }
			update(&simulation)
			applyDeveloperSimulation(simulation)
		}

		func applyDeveloperCustomPopup(title: String, markdown: String) {
			communication.enqueuePopup(
				LauncherPopup(
					id: "developer-custom-popup",
					title: title,
					content: .markdown(markdown),
					dismissTitle: "Done",
					actionTitle: nil,
					actionURL: nil
				)
			)
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
					await log.error(
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
					await log.error(
						"Failed to load developer artwork: \(error.localizedDescription)"
					)
				}
			} catch {
				await log.error(
					"Failed to load developer branding: \(error.localizedDescription)"
				)
			}
		}

		private func applyDeveloperRegionState(_ simulation: inout DeveloperSimulationState) {
			settings.canaryFeaturesEnabled = simulation.canaryFeaturesEnabled
			settings.chinaClientsEnabled = simulation.chinaClientsEnabled
			settings.taiwanClientEnabled = simulation.taiwanClientEnabled
			if !simulation.selectableRegions.contains(simulation.selectedRegion) {
				simulation.selectedRegion = .global
			}
			if installation.region != simulation.selectedRegion {
				lifecycle.activity = .idle
				_ = installation.selectRegion(simulation.selectedRegion)
			}
			for region in GameRegion.allCases {
				installation.setRegionInstalled(
					region,
					simulation.installedRegions.contains(region)
				)
			}
		}

		private func applyDeveloperPreferences(_ simulation: DeveloperSimulationState) {
			settings.showsServerResetCountdown = simulation.showStatusPill
			settings.showsGameVersion = simulation.showVersionPill
			settings.showsPlayingMusic = simulation.showMusicPill
			settings.usesDynamicTheme = simulation.usesDynamicTheme
			developerAccessibilityMusicTitle =
				simulation.longAccessibilityText
				? "A very long Arknights soundtrack title for keyboard and layout checks"
				: "Developer preview soundtrack"
		}

		private func applyDeveloperFailure(
			_ projection: DeveloperSimulationProjection,
			region: GameRegion
		) {
			guard let code = projection.failureCode, let operation = projection.failureOperation
			else {
				lifecycle.clearFailure()
				return
			}
			let isConfiguration = operation == .configurationRefresh
			let existingFailure = lifecycle.failure
			let failureID: UUID
			if let existingFailure,
				existingFailure.code == code,
				existingFailure.context.operation == operation,
				existingFailure.context.region == region.supportRegion
			{
				failureID = existingFailure.id
			} else {
				failureID = UUID()
			}
			lifecycle.presentation.failure = LauncherFailurePresentation(
				id: failureID,
				message: isConfiguration
					? "The selected game configuration could not be loaded."
					: "The Windows runtime exited with status 1.",
				code: code,
				context: SupportContext(operation: operation, region: region.supportRegion),
				actions: isConfiguration
					? [.retry, .openTroubleshooting, .reportProblem]
					: [.retry, .openTroubleshooting, .repair, .reportProblem],
				blocksGameLaunch: true
			)
		}

		private func applyDeveloperPopup(_ simulation: DeveloperSimulationState) {
			switch simulation.popup {
			case .none:
				return
			case .announcement:
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
							string: "https://github.com/LuMiSxh/Arknights-MacOS-Client/issues"
						)
					)
				)
			case .custom:
				break
			}
		}

		private func simulatedActivity(for simulation: DeveloperSimulationState) -> LauncherActivity
		{
			switch simulation.lifecycle {
			case .ready, .paused: .idle
			case .installing:
				.installing(id: UUID(), stage: simulation.installationPhase.state)
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
