// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

extension LauncherViewModel {
	func checkGameUpdates() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.gameUpdate)
				return
			}
		#endif
		guard !isDownloading else { return }
		activeRefreshID = nil
		refreshTask?.cancel()
		refreshTask = Task { [weak self] in
			await self?.refresh(forceGameUpdateCheck: true)
		}
	}

	func checkLauncherUpdates() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.launcherUpdate)
				return
			}
		#endif
		guard !isCheckingLauncherUpdates else { return }
		guard
			let endpointString = Bundle.main.object(forInfoDictionaryKey: "LauncherUpdatesURL")
				as? String,
			let endpoint = URL(string: endpointString)
		else {
			launcherUpdateStatus = "Update source unavailable"
			return
		}

		launcherUpdateTask?.cancel()
		isCheckingLauncherUpdates = true
		launcherUpdateStatus = "Checking…"
		launcherUpdateTask = Task { [weak self] in
			guard let self else { return }
			defer { isCheckingLauncherUpdates = false }
			do {
				guard let release = try await updateChecker.latestRelease(from: endpoint) else {
					launcherUpdate = nil
					launcherUpdateStatus = "No releases available"
					await log.info("Launcher update check completed; no releases available")
					return
				}
				let currentVersion =
					Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
					as? String ?? "0"
				if !release.isDraft && !release.isPrerelease
					&& updateChecker.isNewer(release.version, than: currentVersion)
				{
					launcherUpdate = release
					launcherUpdateStatus = "Version \(release.version) available"
					presentLauncherUpdateIfNeeded(release)
				} else {
					launcherUpdate = nil
					launcherUpdateStatus = "Up to date"
				}
				await log.info(
					"Launcher update check completed; status=\(launcherUpdateStatus ?? "Unknown")"
				)
			} catch is CancellationError {
				launcherUpdateStatus = nil
			} catch {
				launcherUpdateStatus = "Couldn’t check for updates"
				await log.error("Launcher update check failed: \(error.localizedDescription)")
			}
		}
	}

	func openLauncherUpdate() {
		guard let url = launcherUpdate?.htmlURL else { return }
		NSWorkspace.shared.open(url)
	}
}
