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
		guard state.activity == .idle else { return }
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
		state.refresh = .idle
		refreshTask?.cancel()
		progress = nil
		state.activity = .installing(
			id: installationID,
			stage: verifyAllExistingFiles ? .verifying : .preparing
		)
		hasPartialDownload = false
		setStatus(verifyAllExistingFiles ? .verifyingInstallation : .preparingInstallation)
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
						self.state.activity = .installing(id: installationID, stage: .downloading)
						self.setStatus(.downloading)
					}
				}
				guard finishInstallation(installationID) else { return }
				isInstalled = true
				hasPartialDownload = false
				installedVersion = configuration.gameLatestVersion
				isGameUpdateAvailable = false
				setStatus(result.downloadedFiles == 0 ? .ready : .updated)
				await log.info(
					"Installation completed; files=\(result.downloadedFiles); bytes=\(result.downloadedBytes)"
				)
				if launchAfterCompletion { launch() }
			} catch is CancellationError {
				guard finishInstallation(installationID) else { return }
				updateInstalledState()
				setStatus(.paused)
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
		guard case .installing(let installationID, _) = state.activity else { return }
		state.activity = .installing(id: installationID, stage: .pausing)
		setStatus(.pausing)
		Task { [log] in await log.info("Installation pause requested") }
		installationTask?.cancel()
	}

	func finishInstallation(_ installationID: UUID) -> Bool {
		guard installationGate.owns(installationID) else { return false }
		installationGate.finish(installationID)
		installationTask = nil
		state.activity = .idle
		return true
	}
}
