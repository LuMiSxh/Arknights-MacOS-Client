// SPDX-License-Identifier: MPL-2.0

import Foundation

extension InstallationController {
	func installOrUpdate() {
		startInstallation(launchAfterCompletion: false)
	}

	func repairGame() {
		startInstallation(launchAfterCompletion: false, verifyAllExistingFiles: true)
	}

	func startInstallation(
		launchAfterCompletion: Bool,
		verifyAllExistingFiles: Bool = false
	) {
		guard lifecycle.activity == .idle else { return }
		guard let installationID = installationGate.begin() else { return }
		guard let configuration else {
			installationGate.finish(installationID)
			lifecycle.show(LauncherError.missingConfiguration)
			return
		}
		let targetDirectory = installDirectory
		if let required = configuration.requiredInstallBytes,
			let available = GameInstaller.availableCapacityBytes(at: targetDirectory),
			available < required
		{
			installationGate.finish(installationID)
			lifecycle.show(
				LauncherError.insufficientDiskSpace(required: required, available: available))
			return
		}
		onMetadataRefreshCancellationRequested?()
		lifecycle.refresh = .idle
		progress = nil
		lifecycle.activity = .installing(
			id: installationID,
			stage: verifyAllExistingFiles ? .verifying : .preparing
		)
		hasPartialDownload = false
		lifecycle.setStatus(
			verifyAllExistingFiles ? .verifyingInstallation : .preparingInstallation)
		Task { [log] in
			await log.info(
				"Installation started; repair=\(verifyAllExistingFiles); target=\(targetDirectory.path)"
			)
		}

		let requestedRegion = region
		installationTask = Task { [weak self] in
			guard let self else { return }
			do {
				let result = try await installer.install(
					configuration: configuration,
					region: requestedRegion,
					into: targetDirectory,
					verifyAllExistingFiles: verifyAllExistingFiles
				) { [weak self] update in
					await MainActor.run {
						guard let self, self.installationGate.owns(installationID) else { return }
						self.progress = update
						self.lifecycle.activity = .installing(
							id: installationID,
							stage: .downloading
						)
						self.lifecycle.setStatus(.downloading)
					}
				}
				guard finishInstallation(installationID) else { return }
				isInstalled = true
				hasPartialDownload = false
				installedVersion = configuration.gameLatestVersion
				isGameUpdateAvailable = false
				lifecycle.setStatus(result.downloadedFiles == 0 ? .ready : .updated)
				await log.info(
					"Installation completed; files=\(result.downloadedFiles); bytes=\(result.downloadedBytes)"
				)
				if launchAfterCompletion { onLaunchRequested?() }
			} catch is CancellationError {
				guard finishInstallation(installationID) else { return }
				updateInstalledState()
				lifecycle.setStatus(.paused)
				await log.info("Installation paused")
			} catch {
				guard finishInstallation(installationID) else { return }
				lifecycle.show(
					error,
					context: verifyAllExistingFiles
						? "Game repair failed" : "Game installation failed"
				)
			}
		}
	}

	func cancelDownload() {
		guard isDownloading else { return }
		guard case .installing(let installationID, _) = lifecycle.activity else { return }
		lifecycle.activity = .installing(id: installationID, stage: .pausing)
		lifecycle.setStatus(.pausing)
		Task { [log] in await log.info("Installation pause requested") }
		installationTask?.cancel()
	}

	@discardableResult
	func finishInstallation(_ installationID: UUID) -> Bool {
		guard installationGate.owns(installationID) else { return false }
		installationGate.finish(installationID)
		installationTask = nil
		lifecycle.activity = .idle
		return true
	}
}
