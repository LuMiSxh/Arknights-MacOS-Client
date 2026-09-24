// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

/// Coordinates the Rosetta preflight and installation flow for the bundled x86-64 Wine runtime.
/// Lifecycle state lives in `LauncherLifecycleStore` so launch and setup share one readiness
/// source without this feature depending on the root launcher model.
@MainActor
@Observable
final class IntelTranslationController {
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

	init(
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

	var state: IntelTranslationState {
		lifecycle.intelTranslationState
	}
	var allowsWine: Bool { state.allowsWine }

	@discardableResult
	func refreshAvailability(force: Bool = false) async -> IntelTranslationState {
		if !force,
			lifecycle.intelTranslationState != .checking,
			lifecycle.intelTranslationState != .waitingForLauncherCheck
		{
			return lifecycle.intelTranslationState
		}

		lifecycle.intelTranslationState = .checking
		let task: Task<IntelTranslationCheck, Never>
		if let checkTask {
			task = checkTask
		} else {
			task = Task { [checkIntelTranslation] in await checkIntelTranslation() }
			checkTask = task
		}

		let check = await task.value
		checkTask = nil
		lifecycle.intelTranslationState = check.state
		if check.state != .rosettaMissing {
			lifecycle.rosettaInstallationState = .idle
		}
		updatePreflightFailure(for: check)
		await log.info(
			"Intel translation preflight; state=\(check.state.diagnosticName) \(check.diagnostics)"
		)
		return check.state
	}

	@discardableResult
	func installRosetta() async -> IntelTranslationState {
		guard lifecycle.intelTranslationState == .rosettaMissing else {
			return lifecycle.intelTranslationState
		}

		let operationID = installationID ?? UUID()
		installationID = operationID
		lifecycle.rosettaInstallationState = .installing
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
			await log.info(
				"Rosetta installation finished; status=\(result.status) output=\(output)")
			guard result.status == 0 else {
				let message =
					"Apple’s installer exited with status \(String(result.status)). Use the Terminal command below or check the launcher log for details."
				lifecycle.rosettaInstallationState = .failed(message)
				presentRosettaFailure(
					message: message,
					diagnostic: "Rosetta installer exited with status \(result.status): \(output)",
					id: operationID
				)
				return lifecycle.intelTranslationState
			}
			lifecycle.rosettaInstallationState = .idle
			return await refreshAvailability(force: true)
		} catch is CancellationError {
			installationTask = nil
			installationID = nil
			lifecycle.rosettaInstallationState = .idle
			return lifecycle.intelTranslationState
		} catch {
			installationTask = nil
			installationID = nil
			let message =
				"Apple’s Rosetta installer could not start. Use the Terminal command below or check the launcher log for details."
			lifecycle.rosettaInstallationState = .failed(message)
			await log.error("Rosetta installation failed: \(error.localizedDescription)")
			presentRosettaFailure(
				message: message,
				diagnostic: error.localizedDescription,
				id: operationID
			)
			return lifecycle.intelTranslationState
		}
	}

	@discardableResult
	func retryRosettaFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.failure, failure.id == id else { return false }
		guard failure.context.operation == .rosettaInstallation else { return false }
		guard failure.actions.contains(.retry), canInstallRosetta else { return false }
		guard lifecycle.consumeFailure(id: id) != nil else { return false }
		Task { [weak self, log] in
			await log.info("Recovery selected; action=retry operation=rosetta-installation")
			_ = await self?.installRosetta()
		}
		return true
	}

	@discardableResult
	func retryAvailabilityFailure(id: UUID) -> Bool {
		guard let failure = lifecycle.failure, failure.id == id else { return false }
		guard failure.context.operation == .intelTranslationPreflight else { return false }
		guard failure.actions.contains(.retry), lifecycle.activity == .idle else { return false }
		guard lifecycle.consumeFailure(id: id) != nil else { return false }
		Task { [weak self, log] in
			await log.info("Recovery selected; action=retry operation=intel-translation-preflight")
			_ = await self?.refreshAvailability(force: true)
		}
		return true
	}

	var statusTitle: String? {
		if lifecycle.rosettaInstallationState.isInstalling {
			return "Installing Rosetta 2…"
		}
		if lifecycle.rosettaInstallationState.failureMessage != nil {
			return "Rosetta installation failed"
		}
		return switch lifecycle.intelTranslationState {
		case .waitingForLauncherCheck, .checking:
			"Checking Intel compatibility…"
		case .available:
			nil
		case .rosettaMissing:
			"Rosetta 2 required"
		case .gameTestModeEnabled:
			"Legacy Game Test Mode is active"
		case .unavailable:
			"Intel compatibility unavailable"
		case .unsupportedOS:
			"Windows runtime unsupported"
		}
	}

	var statusDetail: String? {
		if lifecycle.rosettaInstallationState.isInstalling {
			return "Apple’s software update tool is installing the Intel compatibility layer."
		}
		if let failure = lifecycle.rosettaInstallationState.failureMessage { return failure }
		return switch lifecycle.intelTranslationState {
		case .waitingForLauncherCheck, .checking:
			"The launcher is verifying that the bundled Wine runtime can start."
		case .available:
			nil
		case .rosettaMissing:
			"Install Rosetta 2, then check again."
		case .gameTestModeEnabled:
			"This macOS 27 test mode disables Rosetta. Turn it off, restart your Mac, then check again."
		case .unavailable:
			"macOS could not start an Intel test process. Check Rosetta, restart your Mac, then check again."
		case .unsupportedOS:
			"This macOS version no longer provides the general Rosetta support Wine requires."
		}
	}

	var canRetryAvailabilityCheck: Bool {
		guard !lifecycle.rosettaInstallationState.isInstalling else { return false }
		return switch lifecycle.intelTranslationState {
		case .rosettaMissing, .gameTestModeEnabled, .unavailable:
			true
		case .waitingForLauncherCheck, .checking, .available, .unsupportedOS:
			false
		}
	}

	var canInstallRosetta: Bool {
		lifecycle.intelTranslationState == .rosettaMissing
			&& !lifecycle.rosettaInstallationState.isInstalling
	}

	var supportCode: SupportCode? {
		switch lifecycle.intelTranslationState {
		case .rosettaMissing, .gameTestModeEnabled, .unavailable, .unsupportedOS:
			.limpet
		case .waitingForLauncherCheck, .checking, .available:
			nil
		}
	}

	var installationActionTitle: String {
		lifecycle.rosettaInstallationState.failureMessage == nil
			? "Install Rosetta 2…"
			: "Try Installation Again…"
	}

	var launchError: LauncherError {
		switch lifecycle.intelTranslationState {
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
			if lifecycle.failure?.context.operation == .intelTranslationPreflight {
				lifecycle.clearFailure()
			}
			return
		}
		guard lifecycle.readiness.isInstalled else { return }
		guard check.state != .waitingForLauncherCheck, check.state != .checking else { return }
		guard
			lifecycle.failure == nil
				|| lifecycle.failure?.context.operation == .intelTranslationPreflight
		else { return }

		let error = launchError
		var actions: [RecoveryAction] = [.retry, .openTroubleshooting, .reportProblem]
		if check.state == .rosettaMissing { actions.insert(.installRosetta, at: 0) }
		let existingID =
			lifecycle.failure?.message == error.errorDescription
			? lifecycle.failure?.id
			: nil
		lifecycle.presentFailure(
			LauncherFailurePresentation(
				id: existingID ?? UUID(),
				message: error.errorDescription
					?? "The operation could not be completed because of an unexpected error.",
				code: .limpet,
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
				code: .limpet,
				context: SupportContext(operation: .rosettaInstallation, region: nil),
				actions: [.retry, .openTroubleshooting, .reportProblem],
				blocksGameLaunch: true
			),
			diagnostic: diagnostic
		)
	}
}
