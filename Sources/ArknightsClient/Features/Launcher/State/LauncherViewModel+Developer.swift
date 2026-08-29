// SPDX-License-Identifier: MPL-2.0

#if DEBUG
	import AppKit
	import Foundation

	extension LauncherViewModel {
		func applyDeveloperScenario(_ scenario: DeveloperScenario) {
			developerScenario = scenario
			communication.resetPopupQueueForDeveloper()
			installation.configuration = Self.developerConfiguration
			installation.progress = nil
			gameSession.runtimeName = "Wine 11.15 + DXMT 0.80"
			installation.isInstalled = true
			installation.installedVersion = Self.developerConfiguration.gameLatestVersion
			installation.isGameUpdateAvailable = false
			communication.launcherUpdateVersion = nil
			communication.launcherUpdateStatus = "Up to date"
			communication.isCheckingLauncherUpdates = false
			lifecycle.intelTranslationState = .available
			lifecycle.activity = .idle
			lifecycle.refresh = .idle
			lifecycle.setStatus(.ready)

			switch scenario {
			case .ready:
				break
			case .launcherUpdate:
				communication.launcherUpdateVersion = "0.2.0"
				communication.launcherUpdateStatus = "Version 0.2.0 available"
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
			case .customPopup:
				break
			case .gameUpdate:
				installation.installedVersion = "041.2.0"
				installation.isGameUpdateAvailable = true
				lifecycle.setStatus(.updateAvailable)
			case .downloading:
				installation.installedVersion = "041.2.0"
				installation.isGameUpdateAvailable = true
				lifecycle.activity = .installing(id: UUID(), stage: .downloading)
				lifecycle.setStatus(.downloading)
				installation.progress = DownloadProgress(
					downloadedBytes: 1_731_000_000,
					totalBytes: 4_026_000_000,
					completedFiles: 128,
					totalFiles: 291,
					currentFile: "Arknights_Data/data.unity3d"
				)
			case .paused:
				installation.installedVersion = "041.2.0"
				installation.isGameUpdateAvailable = true
				installation.hasPartialDownload = true
				lifecycle.setStatus(.paused)
			case .launching:
				lifecycle.activity = .launchingGame(sessionID: UUID(), processIdentifier: nil)
				lifecycle.setStatus(.startingGame)
			case .failure:
				lifecycle.presentation.failure = LauncherFailurePresentation(
					id: UUID(),
					message: "The Windows runtime exited with status 1. See wine.log.",
					code: .crux,
					context: SupportContext(
						operation: .runtimeExit,
						region: installation.region.supportRegion
					),
					actions: [.retry, .openTroubleshooting, .repair, .reportProblem],
					blocksGameLaunch: true
				)
			case .accessibility:
				settings.showsPlayingMusic = true
				settings.showsGameVersion = true
				settings.showsServerResetCountdown = true
				currentMusicTitle =
					"A very long Arknights soundtrack title for Dynamic Type and keyboard layout checks"
			case .onboardingRosetta:
				installation.isInstalled = false
				installation.hasPartialDownload = false
				installation.installedVersion = nil
				lifecycle.setStatus(.install)
				if scenario == .onboardingRosetta {
					lifecycle.intelTranslationState = .rosettaMissing
				}
			}
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
			if await customization.loadCustomArtwork() { return }
			let artworkCache = customization.artworkCache
			let region = installation.region
			do {
				let currentBranding = try await api.branding(region: region)
				guard isDeveloperMode, installation.region == region else { return }
				refreshController.branding = currentBranding
				do {
					let logoData = try await artworkCache.officialLogoData(
						for: region
					)
					guard installation.region == region else { return }
					customization.officialLogo = NSImage(data: logoData)
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
