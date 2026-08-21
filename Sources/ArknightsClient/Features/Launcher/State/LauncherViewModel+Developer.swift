// SPDX-License-Identifier: MPL-2.0

#if DEBUG
	import AppKit
	import Foundation

	extension LauncherViewModel {
		func applyDeveloperScenario(_ scenario: DeveloperScenario) {
			developerScenario = scenario
			pendingPopups.removeAll()
			popup = nil
			configuration = Self.developerConfiguration
			progress = nil
			runtimeName = "Wine 11.15 + DXMT 0.80"
			isInstalled = true
			installedVersion = Self.developerConfiguration.gameLatestVersion
			isGameUpdateAvailable = false
			launcherUpdate = nil
			launcherUpdateStatus = "Up to date"
			isCheckingLauncherUpdates = false
			intelTranslationState = .available
			state.activity = .idle
			state.refresh = .idle
			setStatus(.ready)

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
				launcherUpdate = release
				launcherUpdateStatus = "Version 0.2.0 available"
				enqueuePopup(Self.developerUpdatePopup(release))
			case .announcement:
				enqueuePopup(
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
					enqueuePopup(
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
				installedVersion = "041.2.0"
				isGameUpdateAvailable = true
				setStatus(.updateAvailable)
			case .downloading:
				installedVersion = "041.2.0"
				isGameUpdateAvailable = true
				state.activity = .installing(id: UUID(), stage: .downloading)
				setStatus(.downloading)
				progress = DownloadProgress(
					downloadedBytes: 1_731_000_000,
					totalBytes: 4_026_000_000,
					completedFiles: 128,
					totalFiles: 291,
					currentFile: "Arknights_Data/data.unity3d"
				)
			case .paused:
				installedVersion = "041.2.0"
				isGameUpdateAvailable = true
				hasPartialDownload = true
				setStatus(.paused)
			case .migrating:
				state.activity = .preparingGame(sessionID: UUID())
				setStatus(.preparingWine)
			case .launching:
				state.activity = .launchingGame(sessionID: UUID(), processIdentifier: nil)
				setStatus(.startingGame)
			case .running:
				state.activity = .runningGame(sessionID: UUID(), processIdentifier: 42)
				setStatus(.running)
			case .failure:
				state.presentation.failureMessage =
					"The Windows runtime exited unexpectedly. Check the logs for details."
			case .notInstalled:
				isInstalled = false
				hasPartialDownload = false
				installedVersion = nil
				setStatus(.install)
			case .musicPlayer:
				showsPlayingMusic = true
				currentMusicTitle = "Arknights EP – Reforge"
				currentMusicVideoID = "developer-preview"
			case .onboarding, .onboardingRosetta:
				isInstalled = false
				hasPartialDownload = false
				installedVersion = nil
				setStatus(.install)
				if scenario == .onboardingRosetta {
					intelTranslationState = .rosettaMissing
				}
			}
		}

		func applyDeveloperCustomPopup(title: String, markdown: String) {
			enqueuePopup(
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
			if await loadCustomArtwork() { return }
			do {
				let currentBranding = try await api.branding(region: region)
				guard isDeveloperMode else { return }
				branding = currentBranding
				do {
					let logoData = try await artworkCache.officialLogoData()
					officialLogo = NSImage(data: logoData)
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
						setHeroArtwork(
							image,
							themeCacheKey: Self.officialThemeCacheKey(
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
