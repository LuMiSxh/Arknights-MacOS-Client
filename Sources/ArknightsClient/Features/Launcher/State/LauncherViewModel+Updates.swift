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
		state.refresh = .idle
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
		_ = startLauncherUpdateCheck()
	}

	/// Performs the mandatory preflight used by first-run setup. If the normal automatic
	/// check is already running, both callers await the same request instead of racing two
	/// GitHub API calls or presenting conflicting results.
	func launcherUpdateCheckForOnboarding() async -> LauncherUpdateCheckOutcome {
		#if DEBUG
			if isOnboardingPreview { return .current }
		#endif
		return await startLauncherUpdateCheck().value
	}

	func openLauncherUpdate() {
		guard let url = launcherUpdate?.htmlURL else { return }
		NSWorkspace.shared.open(url)
	}

	private func startLauncherUpdateCheck() -> Task<LauncherUpdateCheckOutcome, Never> {
		if isCheckingLauncherUpdates, let launcherUpdateTask {
			return launcherUpdateTask
		}

		launcherUpdateTask?.cancel()
		isCheckingLauncherUpdates = true
		launcherUpdateStatus = L10n.string(.Launcher.launcherUpdateStatusChecking)
		let task = Task { [weak self] in
			guard let self else { return LauncherUpdateCheckOutcome.failed }
			defer { isCheckingLauncherUpdates = false }
			guard
				let endpointString = Bundle.main.object(
					forInfoDictionaryKey: "LauncherUpdatesURL"
				) as? String,
				let endpoint = URL(string: endpointString)
			else {
				launcherUpdate = nil
				launcherUpdateStatus = L10n.string(.Launcher.launcherUpdateStatusSourceUnavailable)
				await log.error("Launcher update check failed: update source unavailable")
				return .unavailable
			}

			do {
				guard let release = try await updateChecker.latestRelease(from: endpoint) else {
					launcherUpdate = nil
					launcherUpdateStatus = L10n.string(.Launcher.launcherUpdateStatusNoReleases)
					await log.info("Launcher update check completed; no releases available")
					return .current
				}
				let currentVersion = Bundle.main.shortVersionString ?? "0"
				if !release.isDraft && !release.isPrerelease
					&& updateChecker.isNewer(release.version, than: currentVersion)
				{
					launcherUpdate = release
					launcherUpdateStatus = L10n.string(
						.Launcher.launcherUpdateStatusVersionAvailable(release.version)
					)
					presentLauncherUpdateIfNeeded(release)
					await log.info(
						"Launcher update check completed; status=Version \(release.version) available"
					)
					return .updateAvailable(release)
				}

				launcherUpdate = nil
				launcherUpdateStatus = L10n.string(.Launcher.launcherUpdateStatusUpToDate)
				await log.info("Launcher update check completed; status=Up to date")
				return .current
			} catch is CancellationError {
				launcherUpdateStatus = nil
				return .failed
			} catch {
				launcherUpdate = nil
				launcherUpdateStatus = L10n.string(.Launcher.launcherUpdateStatusFailed)
				await log.error("Launcher update check failed: \(error.localizedDescription)")
				return .failed
			}
		}
		launcherUpdateTask = task
		return task
	}
}
