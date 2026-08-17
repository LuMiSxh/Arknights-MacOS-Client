// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	func installOrUpdate() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.downloading)
				return
			}
		#endif
		startInstallation(launchAfterCompletion: false)
	}

	func repairGame() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.downloading)
				return
			}
		#endif
		startInstallation(launchAfterCompletion: false, verifyAllExistingFiles: true)
	}

	func startInstallation(
		launchAfterCompletion: Bool,
		verifyAllExistingFiles: Bool = false
	) {
		guard let installationID = installationGate.begin() else { return }
		guard let configuration else {
			installationGate.finish(installationID)
			show(LauncherError.missingConfiguration)
			return
		}
		let targetDirectory = installDirectory
		if let required = configuration.requiredInstallBytes,
			let available = GameInstaller.availableCapacityBytes(at: targetDirectory),
			available < required
		{
			installationGate.finish(installationID)
			show(LauncherError.insufficientDiskSpace(required: required, available: available))
			return
		}
		activeRefreshID = nil
		refreshTask?.cancel()
		progress = nil
		phase = .downloading
		hasPartialDownload = false
		activityMessage = verifyAllExistingFiles ? "Verifying…" : "Preparing…"
		Task { [log] in
			await log.info(
				"Installation started; repair=\(verifyAllExistingFiles); target=\(targetDirectory.path)"
			)
		}

		installationTask = Task { [weak self] in
			guard let self else { return }
			do {
				let result = try await installer.install(
					configuration: configuration,
					region: region,
					into: targetDirectory,
					verifyAllExistingFiles: verifyAllExistingFiles
				) { [weak self] update in
					await MainActor.run {
						guard let self, self.installationGate.owns(installationID) else {
							return
						}
						self.progress = update
						self.activityMessage = "Downloading…"
					}
				}
				guard finishInstallation(installationID) else { return }
				isInstalled = true
				hasPartialDownload = false
				installedVersion = configuration.gameLatestVersion
				isGameUpdateAvailable = false
				phase = .ready
				activityMessage = result.downloadedFiles == 0 ? "Ready" : "Updated"
				await log.info(
					"Installation completed; files=\(result.downloadedFiles); bytes=\(result.downloadedBytes)"
				)
				if launchAfterCompletion { launch() }
			} catch is CancellationError {
				guard finishInstallation(installationID) else { return }
				updateInstalledState()
				phase = .ready
				activityMessage = "Paused"
				await log.info("Installation paused")
			} catch {
				guard finishInstallation(installationID) else { return }
				show(error)
			}
		}
	}

	func cancelDownload() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.paused)
				return
			}
		#endif
		guard isDownloading else { return }
		activityMessage = "Pausing…"
		Task { [log] in await log.info("Installation pause requested") }
		installationTask?.cancel()
	}

	func finishInstallation(_ installationID: UUID) -> Bool {
		guard installationGate.owns(installationID) else { return false }
		installationGate.finish(installationID)
		installationTask = nil
		return true
	}
}
