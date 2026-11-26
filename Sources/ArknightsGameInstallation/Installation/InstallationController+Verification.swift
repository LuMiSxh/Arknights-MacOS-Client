// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

extension InstallationController {
	/// Hashes the installed files against the manifest. It holds the same activity as install and
	/// repair, so Play and the other game-file actions wait for it.
	package func verifyGameFiles() {
		guard canInstall, isInstalled, let configuration else { return }
		let verificationID = UUID()
		let targetDirectory = installDirectory
		let requestedRegion = region
		cancelInstalledStateRefresh()
		onMetadataRefreshCancellationRequested?()
		lifecycle.state.refresh = .idle
		progress = nil
		progressSequence = 0
		fileVerification = nil
		guard
			let lease = lifecycle.begin(.installing(id: verificationID, stage: .verifying))
		else { return }
		activityLease = lease
		lifecycle.setStatus(.verifyingInstallation)
		log.info(.install, "verify-started", ["path": targetDirectory])

		installationTask = Task { [weak self] in
			guard let self else { return }
			do {
				let verification = try await installer.verify(
					configuration: configuration,
					region: requestedRegion,
					in: targetDirectory,
					progress: installationProgressHandler(id: verificationID, lease: lease)
				)
				guard finishInstallation(verificationID) else { return }
				fileVerification = verification
				lifecycle.setStatus(.ready)
				log.info(
					.install, "verify-completed",
					["damaged": verification.damagedPaths.count])
			} catch is CancellationError {
				guard finishInstallation(verificationID) else { return }
				progress = nil
				lifecycle.setStatus(.ready)
				log.info(.install, "verify-cancelled")
			} catch {
				guard finishInstallation(verificationID) else { return }
				presentInstallationFailure(
					error,
					id: verificationID,
					operation: .verify,
					region: requestedRegion
				)
			}
		}
	}

	@discardableResult
	package func retryVerificationFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.state.presentation.failure, failure.id == id else {
			return false
		}
		guard failure.context.operation == .verify else { return false }
		guard failure.context.region == region.supportRegion else { return false }
		guard failure.actions.contains(.retry), canInstall, isInstalled else { return false }
		guard lifecycle.consumeFailure(id: id) != nil else { return false }
		log.info(
			.install, "recovery-selected",
			["action": "retry", "operation": "verify", "server": region.rawValue])
		verifyGameFiles()
		return true
	}
}
