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
			activeGameSessionID = nil
			isStoppingGame = false
			phase = .ready
			activityMessage = "Ready"

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
				activityMessage = "Update available"
			case .downloading:
				installedVersion = "041.2.0"
				isGameUpdateAvailable = true
				phase = .downloading
				activityMessage = "Downloading…"
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
				activityMessage = "Paused"
			case .migrating:
				activeGameSessionID = UUID()
				phase = .migrating
				activityMessage = "Preparing Wine setup…"
			case .launching:
				activeGameSessionID = UUID()
				phase = .launching
				activityMessage = "Starting…"
			case .running:
				activeGameSessionID = UUID()
				phase = .running(processIdentifier: 42)
				activityMessage = "Running"
			case .failure:
				phase = .failed(
					"The Windows runtime exited unexpectedly. Check the logs for details.")
				activityMessage = "The Windows runtime exited unexpectedly."
			case .notInstalled:
				isInstalled = false
				hasPartialDownload = false
				installedVersion = nil
				activityMessage = "Install"
			case .onboarding:
				isInstalled = false
				hasPartialDownload = false
				installedVersion = nil
				activityMessage = "Install"
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
			if loadCustomArtwork() { return }
			guard let currentBranding = try? await api.branding(region: region), isDeveloperMode
			else { return }
			branding = currentBranding
			if let logoData = try? await artworkCache.officialLogoData() {
				officialLogo = NSImage(data: logoData)
			}
			if let imageData = try? await artworkCache.imageData(
				for: currentBranding,
				region: region
			), let image = NSImage(data: imageData) {
				setHeroArtwork(
					image,
					themeCacheKey: Self.officialThemeCacheKey(for: region)
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
