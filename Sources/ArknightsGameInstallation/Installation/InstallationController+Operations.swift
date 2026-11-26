// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

extension InstallationController {
	package func installOrUpdate() {
		startInstallation(launchAfterCompletion: false)
	}

	package func repairGame() {
		startInstallation(launchAfterCompletion: false, verifyAllExistingFiles: true)
	}

	package func startInstallation(
		launchAfterCompletion: Bool,
		verifyAllExistingFiles: Bool = false,
		operationOverride: SupportOperation? = nil
	) {
		guard lifecycle.activity == .idle else { return }
		let installationID = UUID()
		cancelInstalledStateRefresh()
		let requestedRegion = region
		let operation: SupportOperation =
			operationOverride
			?? (verifyAllExistingFiles ? .repair : (isInstalled ? .update : .install))
		guard let configuration else {
			presentInstallationFailure(
				InstallerError.missingConfiguration,
				id: installationID,
				operation: operation,
				region: requestedRegion
			)
			return
		}
		let targetDirectory = installDirectory
		onMetadataRefreshCancellationRequested?()
		lifecycle.state.refresh = .idle
		progress = nil
		progressSequence = 0
		guard
			let lease = lifecycle.begin(
				.installing(
					id: installationID,
					stage: verifyAllExistingFiles ? .verifying : .preparing
				))
		else { return }
		activityLease = lease
		if installPresence == .partialDownload { installPresence = .absent }
		lifecycle.setStatus(
			verifyAllExistingFiles ? .verifyingInstallation : .preparingInstallation)
		log.info(
			.install, "started",
			["repair": verifyAllExistingFiles, "path": targetDirectory])

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
						guard let self, self.ownsInstallation(installationID) else { return }
						guard
							(update.sequence == 0 && self.progressSequence == 0)
								|| update.sequence >= self.progressSequence
						else {
							return
						}
						self.progressSequence = update.sequence
						self.progress = update
						let activity = LauncherActivity.installing(
							id: installationID,
							stage: update.isVerifying ? .verifying : .downloading
						)
						if self.lifecycle.activity != activity {
							self.lifecycle.update(lease, to: activity)
						}
						let status: LauncherStatus =
							update.isVerifying ? .verifyingInstallation : .downloading
						if self.lifecycle.state.presentation.status != status {
							self.lifecycle.setStatus(status)
						}
					}
				}
				guard finishInstallation(installationID) else { return }
				installPresence = .installed(version: configuration.gameLatestVersion)
				setRegionInstalled(requestedRegion, true)
				isGameUpdateAvailable = false
				lifecycle.setStatus(.ready)

				log.info(
					.install, "completed",
					["files": result.downloadedFiles, "bytes": result.downloadedBytes])
				if launchAfterCompletion { onLaunchRequested?() }
			} catch is CancellationError {
				await updateInstalledState().value
				guard finishInstallation(installationID) else { return }
				// A paused verification pass says nothing about partial-download progress.
				if progress?.isVerifying == true { progress = nil }
				lifecycle.setStatus(.paused)
				log.info(.install, "paused")
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
	package func retryInstallationFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.state.presentation.failure, failure.id == id else {
			return false
		}
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
		log.info(
			.install, "recovery-selected",
			[
				"action": "retry", "operation": failure.context.operation.rawValue,
				"server": region.rawValue,
			]
		)
		startInstallation(
			launchAfterCompletion: false,
			verifyAllExistingFiles: failure.context.operation == .repair,
			operationOverride: failure.context.operation
		)
		return true
	}

	package func cancelDownload() {
		guard isDownloading else { return }
		guard case .installing(let installationID, _) = lifecycle.activity else { return }
		if let lease = activityLease {
			lifecycle.update(lease, to: .installing(id: installationID, stage: .pausing))
		}
		lifecycle.setStatus(.pausing)
		log.info(.install, "pause-requested")
		installationTask?.cancel()
	}

	// The installing activity carries its operation ID, so a stale task that lost a race to a
	// newer operation can never finish or update it.
	func ownsInstallation(_ installationID: UUID) -> Bool {
		guard case .installing(let activeID, _) = lifecycle.activity else { return false }
		return activeID == installationID
	}

	@discardableResult
	func finishInstallation(_ installationID: UUID) -> Bool {
		guard ownsInstallation(installationID), let lease = activityLease else { return false }
		installationTask = nil
		activityLease = nil
		lifecycle.end(lease)
		return true
	}
}
