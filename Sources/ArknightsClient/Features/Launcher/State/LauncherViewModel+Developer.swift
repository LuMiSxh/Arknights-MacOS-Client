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
			communication.launcherUpdate = nil
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
				let release = LauncherRelease(
					tagName: "v0.2.0",
					htmlURL: URL(
						string: "https://github.com/LuMiSxh/Arknights-MacOS-Client/releases")!,
					body:
						"## What’s new\n\n- Faster game startup\n- Improved embedded browser rendering\n- More reliable runtime migrations",
					isDraft: false,
					isPrerelease: false
				)
				communication.launcherUpdate = release
				communication.launcherUpdateStatus = "Version 0.2.0 available"
				communication.enqueuePopup(Self.developerUpdatePopup(release))
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
			case .yostarNotice:
				let notice = LauncherNoticeFormatter.notice(
					fromHTML:
						"<h2>Scheduled maintenance</h2><p>The game will be unavailable during maintenance.</p>"
				)
				if let notice {
					communication.enqueuePopup(
						LauncherPopup(
							id: "developer-yostar-notice",
							title: "Notice",
							content: .attributed(notice.content),
							dismissTitle: "Done",
							actionTitle: nil,
							actionURL: nil
						)
					)
				}
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
			case .migrating:
				lifecycle.activity = .preparingGame(sessionID: UUID())
				lifecycle.setStatus(.preparingWine)
			case .launching:
				lifecycle.activity = .launchingGame(sessionID: UUID(), processIdentifier: nil)
				lifecycle.setStatus(.startingGame)
			case .running:
				lifecycle.activity = .runningGame(sessionID: UUID(), processIdentifier: 42)
				lifecycle.setStatus(.running)
			case .failure:
				lifecycle.presentation.failureMessage =
					"The Windows runtime exited unexpectedly. Check the logs for details."
			case .notInstalled:
				installation.isInstalled = false
				installation.hasPartialDownload = false
				installation.installedVersion = nil
				lifecycle.setStatus(.install)
			case .musicPlayer:
				settings.showsPlayingMusic = true
				currentMusicTitle = "Arknights EP – Reforge"
				currentMusicVideoID = "developer-preview"
			case .onboarding, .onboardingRosetta:
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
			do {
				let currentBranding = try await api.branding(region: installation.region)
				guard isDeveloperMode else { return }
				refreshController.branding = currentBranding
				do {
					let logoData = try await artworkCache.officialLogoData()
					customization.officialLogo = NSImage(data: logoData)
				} catch {
					await log.error(
						"Failed to load developer logo: \(error.localizedDescription)"
					)
				}
				do {
					if let imageData = try await artworkCache.imageData(
						for: currentBranding,
						region: installation.region
					), let image = NSImage(data: imageData),
						let artworkCacheKey = artworkCache.cacheKey(for: currentBranding)
					{
						customization.setHeroArtwork(
							image,
							themeCacheKey: CustomizationController.officialThemeCacheKey(
								for: installation.region,
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

		private static func developerUpdatePopup(_ release: LauncherRelease) -> LauncherPopup {
			LauncherPopup(
				id: "developer-launcher-update",
				title: "Arknights Client \(release.version)",
				content: .markdown(release.body ?? ""),
				dismissTitle: "Later",
				actionTitle: "View Release",
				actionURL: release.htmlURL
			)
		}
	}
#endif
