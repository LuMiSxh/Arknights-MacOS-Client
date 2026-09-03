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
		verifyAllExistingFiles: Bool = false,
		operationOverride: SupportOperation? = nil
	) {
		guard lifecycle.activity == .idle else { return }
		guard let installationID = installationGate.begin() else { return }
		cancelInstalledStateRefresh()
		let requestedRegion = region
		let operation: SupportOperation =
			operationOverride
			?? (verifyAllExistingFiles ? .repair : (isInstalled ? .update : .install))
		guard let configuration else {
			installationGate.finish(installationID)
			presentInstallationFailure(
				LauncherError.missingConfiguration,
				id: installationID,
				operation: operation,
				region: requestedRegion
			)
			return
		}
		let targetDirectory = installDirectory
		guard let required = configuration.requiredInstallBytes else {
			installationGate.finish(installationID)
			presentInstallationFailure(
				LauncherError.invalidResponse,
				id: installationID,
				operation: operation,
				region: requestedRegion
			)
			return
		}
		do {
			let available = try GameInstaller.availableCapacityBytes(at: targetDirectory)
			if available < required {
				installationGate.finish(installationID)
				presentInstallationFailure(
					LauncherError.insufficientDiskSpace(required: required, available: available),
					id: installationID,
					operation: operation,
					region: requestedRegion
				)
				return
			}
		} catch {
			installationGate.finish(installationID)
			presentInstallationFailure(
				error,
				id: installationID,
				operation: operation,
				region: requestedRegion
			)
			return
		}
		onMetadataRefreshCancellationRequested?()
		lifecycle.refresh = .idle
		progress = nil
		progressSequence = 0
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
						guard
							(update.sequence == 0 && self.progressSequence == 0)
								|| update.sequence >= self.progressSequence
						else {
							return
						}
						self.progressSequence = update.sequence
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
				setRegionInstalled(requestedRegion, true)
				hasPartialDownload = false
				installedVersion = configuration.gameLatestVersion
				isGameUpdateAvailable = false
				lifecycle.setStatus(result.downloadedFiles == 0 ? .ready : .updated)
				await log.info(
					"Installation completed; files=\(result.downloadedFiles); bytes=\(result.downloadedBytes)"
				)
				if launchAfterCompletion { onLaunchRequested?() }
			} catch is CancellationError {
				await updateInstalledState().value
				guard finishInstallation(installationID) else { return }
				lifecycle.setStatus(.paused)
				await log.info("Installation paused")
			} catch {
				guard finishInstallation(installationID) else { return }
				presentInstallationFailure(
					error,
					id: installationID,
					operation: operation,
					region: requestedRegion
				)
			}
		}
	}

	@discardableResult
	func retryInstallationFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.failure, failure.id == id else { return false }
		guard failure.actions.contains(.retry), lifecycle.activity == .idle else { return false }
		guard failure.context.region == region.supportRegion else { return false }
		guard
			failure.context.operation == .install || failure.context.operation == .update
				|| failure.context.operation == .repair
		else { return false }
		switch failure.context.operation {
		case .install where isInstalled,
			.update where !isInstalled,
			.repair where !isInstalled:
			return false
		default:
			break
		}
		guard lifecycle.consumeFailure(id: id) != nil else { return false }
		Task { [log] in
			await log.info(
				"Recovery selected; action=retry operation=\(failure.context.operation.rawValue) region=\(region.rawValue)"
			)
		}
		startInstallation(
			launchAfterCompletion: false,
			verifyAllExistingFiles: failure.context.operation == .repair,
			operationOverride: failure.context.operation
		)
		return true
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
