// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Observation

// Lifecycle state lives in `LauncherLifecycleStore` so launch and setup share one readiness
// source without this feature depending on the root launcher model.
@MainActor
@Observable
package final class IntelTranslationController {
	private let lifecycle: LauncherLifecycleStore
	private let checkIntelTranslation: @Sendable () async -> IntelTranslationCheck
	private let installRosettaSystemSoftware:
		@Sendable () async throws -> IntelTranslationProcessResult
	private let log: LauncherLog

	// The task handles are deliberately unobserved: they only deduplicate in-flight work and are
	// cancelled on teardown. The user-visible state remains in the lifecycle store.
	@ObservationIgnored private var checkTask: Task<IntelTranslationCheck, Never>?
	@ObservationIgnored private var installationTask:
		Task<IntelTranslationProcessResult, any Error>?
	@ObservationIgnored private var installationID: UUID?

	package init(
		lifecycle: LauncherLifecycleStore,
		checkIntelTranslation: @escaping @Sendable () async -> IntelTranslationCheck = {
			await RosettaAvailability.check()
		},
		installRosettaSystemSoftware:
			@escaping @Sendable () async throws -> IntelTranslationProcessResult = {
				try await RosettaInstaller.install()
			},
		log: LauncherLog? = nil
	) {
		self.lifecycle = lifecycle
		self.checkIntelTranslation = checkIntelTranslation
		self.installRosettaSystemSoftware = installRosettaSystemSoftware
		self.log = log ?? lifecycle.log
	}

	deinit {
		checkTask?.cancel()
		installationTask?.cancel()
	}

	package var state: IntelTranslationState {
		lifecycle.state.readiness.intelTranslation
	}
	package var allowsWine: Bool { state.allowsWine }

	@discardableResult
	package func refreshAvailability(force: Bool = false) async -> IntelTranslationState {
		if !force,
			lifecycle.state.readiness.intelTranslation != .checking,
			lifecycle.state.readiness.intelTranslation != .waitingForLauncherCheck
		{
			return lifecycle.state.readiness.intelTranslation
		}

		lifecycle.state.readiness.intelTranslation = .checking
		let task: Task<IntelTranslationCheck, Never>
		if let checkTask {
			task = checkTask
		} else {
			task = Task { [checkIntelTranslation] in await checkIntelTranslation() }
			checkTask = task
		}

		let check = await task.value
		checkTask = nil
		applyAvailabilityCheck(check)
		return check.state
	}

	/// Applies real and simulated probe results through the same recovery presentation.
	package func applyAvailabilityCheck(_ check: IntelTranslationCheck) {
		lifecycle.state.readiness.intelTranslation = check.state
		if check.state != .rosettaMissing {
			lifecycle.state.readiness.rosettaInstallation = .idle
		}
		updatePreflightFailure(for: check)
		log.info(
			"Intel translation preflight; state=\(check.state.diagnosticName) \(check.diagnostics)"
		)
	}

	@discardableResult
	package func installRosetta() async -> IntelTranslationState {
		guard lifecycle.state.readiness.intelTranslation == .rosettaMissing else {
			return lifecycle.state.readiness.intelTranslation
		}

		let operationID = installationID ?? UUID()
		installationID = operationID
		lifecycle.state.readiness.rosettaInstallation = .installing
		let task: Task<IntelTranslationProcessResult, any Error>
		if let installationTask {
			task = installationTask
		} else {
			task = Task { [installRosettaSystemSoftware] in
				try await installRosettaSystemSoftware()
			}
			installationTask = task
		}

		do {
			let result = try await task.value
			installationTask = nil
			installationID = nil
			let output = Self.boundedDiagnostics(result.output)
			log.info(
				"Rosetta installation finished; status=\(result.status) output=\(output)")
			guard result.status == 0 else {
				let message =
					"Apple’s installer exited with status \(String(result.status)). Use the Terminal command below or check the launcher log for details."
				lifecycle.state.readiness.rosettaInstallation = .failed(message)
				presentRosettaFailure(
					message: message,
					diagnostic: "Rosetta installer exited with status \(result.status): \(output)",
					id: operationID
				)
				return lifecycle.state.readiness.intelTranslation
			}
			lifecycle.state.readiness.rosettaInstallation = .idle
			return await refreshAvailability(force: true)
		} catch is CancellationError {
			installationTask = nil
			installationID = nil
			lifecycle.state.readiness.rosettaInstallation = .idle
			return lifecycle.state.readiness.intelTranslation
		} catch {
			installationTask = nil
			installationID = nil
			let message =
				"Apple’s Rosetta installer could not start. Use the Terminal command below or check the launcher log for details."
			lifecycle.state.readiness.rosettaInstallation = .failed(message)
			log.error("Rosetta installation failed: \(error.localizedDescription)")
			presentRosettaFailure(
				message: message,
				diagnostic: error.localizedDescription,
				id: operationID
			)
			return lifecycle.state.readiness.intelTranslation
		}
	}

	@discardableResult
	package func retryRosettaFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.state.presentation.failure, failure.id == id else {
			return false
		}
		guard failure.context.operation == .rosettaInstallation else { return false }
		guard failure.actions.contains(.retry), canInstallRosetta else { return false }
		guard lifecycle.consumeFailure(id: id) != nil else { return false }
		Task { [weak self, log] in
			log.info("Recovery selected; action=retry operation=rosetta-installation")
			_ = await self?.installRosetta()
		}
		return true
	}

	@discardableResult
	package func retryAvailabilityFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.state.presentation.failure, failure.id == id else {
			return false
		}
		guard failure.context.operation == .intelTranslationPreflight else { return false }
		guard failure.actions.contains(.retry), lifecycle.activity == .idle else { return false }
		guard lifecycle.consumeFailure(id: id) != nil else { return false }
		Task { [weak self, log] in
			log.info("Recovery selected; action=retry operation=intel-translation-preflight")
			_ = await self?.refreshAvailability(force: true)
		}
		return true
	}

	package var statusDetail: String? {
		if lifecycle.state.readiness.rosettaInstallation.isInstalling {
			return "Apple’s software update tool is installing the Intel compatibility layer."
		}
		if let failure = lifecycle.state.readiness.rosettaInstallation.failureMessage {
			return failure
		}
		return switch lifecycle.state.readiness.intelTranslation {
		case .waitingForLauncherCheck, .checking:
			"The launcher is verifying that the bundled Wine runtime can start."
		case .available:
			nil
		case .rosettaMissing:
			"Install Rosetta 2, then check again."
		case .gameTestModeEnabled:
			"On macOS 27 beta, Legacy Game Test Mode disables Rosetta. If it is enabled, turn it off, restart your Mac, then check again."
		case .unavailable:
			"macOS could not start an Intel test process. Check Rosetta, restart your Mac, then check again."
		case .unsupportedOS:
			"The launcher currently blocks this macOS version. Apple retains Rosetta only for certain legacy games, and whether this Wine and game setup qualifies is unconfirmed."
		}
	}

	package var canInstallRosetta: Bool {
		lifecycle.state.readiness.intelTranslation == .rosettaMissing
			&& !lifecycle.state.readiness.rosettaInstallation.isInstalling
	}

	var launchError: GameRuntimeError {
		switch lifecycle.state.readiness.intelTranslation {
		case .rosettaMissing:
			.rosettaMissing
		case .gameTestModeEnabled:
			.rosettaDisabledByGameTestMode
		case .unsupportedOS:
			.intelTranslationUnsupported
		case .waitingForLauncherCheck, .checking, .available, .unavailable:
			.intelTranslationUnavailable
		}
	}

	private static func boundedDiagnostics(_ output: String) -> String {
		let normalized = output.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !normalized.isEmpty else { return "empty" }
		return String(normalized.prefix(AppConstants.IO.processDiagnosticMaximumCharacters))
	}

	private func updatePreflightFailure(for check: IntelTranslationCheck) {
		if check.state == .available {
			if lifecycle.state.presentation.failure?.context.operation == .intelTranslationPreflight
			{
				lifecycle.clearFailure()
			}
			return
		}
		guard lifecycle.state.readiness.isInstalled else { return }
		guard check.state != .waitingForLauncherCheck, check.state != .checking else { return }
		guard
			lifecycle.state.presentation.failure == nil
				|| lifecycle.state.presentation.failure?.context.operation
					== .intelTranslationPreflight
		else { return }

		let error = launchError
		var actions: [RecoveryAction] = [.retry, .openTroubleshooting, .reportProblem]
		if check.state == .rosettaMissing { actions.insert(.installRosetta, at: 0) }
		let existingID =
			lifecycle.state.presentation.failure?.message == error.errorDescription
			? lifecycle.state.presentation.failure?.id
			: nil
		lifecycle.presentFailure(
			LauncherFailurePresentation(
				id: existingID ?? UUID(),
				message: error.errorDescription
					?? "The operation could not be completed because of an unexpected error.",
				code: check.state == .rosettaMissing ? .rosettaMissing : .intelTranslationBlocked,
				context: SupportContext(operation: .intelTranslationPreflight, region: nil),
				actions: actions,
				blocksGameLaunch: true
			),
			diagnostic: check.diagnostics
		)
	}

	private func presentRosettaFailure(message: String, diagnostic: String, id: UUID) {
		lifecycle.presentFailure(
			LauncherFailurePresentation(
				id: id,
				message: message,
				code: .rosettaMissing,
				context: SupportContext(operation: .rosettaInstallation, region: nil),
				actions: [.retry, .openTroubleshooting, .reportProblem],
				blocksGameLaunch: true
			),
			diagnostic: diagnostic
		)
	}
}
