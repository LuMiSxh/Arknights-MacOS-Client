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
				let message = L10n.string(
					.Launcher.launcherRosettaFailureInstallerExited(String(result.status)))
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
			let message = L10n.string(.Launcher.launcherRosettaFailureInstallerStart)
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

	var statusTitle: String? {
		if lifecycle.rosettaInstallationState.isInstalling {
			return L10n.string(.Launcher.launcherRosettaStatusInstalling)
		}
		if lifecycle.rosettaInstallationState.failureMessage != nil {
			return L10n.string(.Launcher.launcherRosettaStatusInstallationFailed)
		}
		return switch lifecycle.intelTranslationState {
		case .waitingForLauncherCheck, .checking:
			L10n.string(.Launcher.launcherRosettaStatusChecking)
		case .available:
			nil
		case .rosettaMissing:
			L10n.string(.Launcher.launcherRosettaStatusMissing)
		case .gameTestModeEnabled:
			L10n.string(.Launcher.launcherRosettaStatusGameTestMode)
		case .unavailable:
			L10n.string(.Launcher.launcherRosettaStatusUnavailable)
		case .unsupportedOS:
			L10n.string(.Launcher.launcherRosettaStatusUnsupported)
		}
	}

	var statusDetail: String? {
		if lifecycle.rosettaInstallationState.isInstalling {
			return L10n.string(.Launcher.launcherRosettaDetailInstalling)
		}
		if let failure = lifecycle.rosettaInstallationState.failureMessage { return failure }
		return switch lifecycle.intelTranslationState {
		case .waitingForLauncherCheck, .checking:
			L10n.string(.Launcher.launcherRosettaDetailAvailableCheck)
		case .available:
			nil
		case .rosettaMissing:
			L10n.string(.Launcher.launcherRosettaDetailMissing)
		case .gameTestModeEnabled:
			L10n.string(.Launcher.launcherRosettaDetailGameTestMode)
		case .unavailable:
			L10n.string(.Launcher.launcherRosettaDetailUnavailable)
		case .unsupportedOS:
			L10n.string(.Launcher.launcherRosettaDetailUnsupported)
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
			? L10n.string(.Launcher.launcherRosettaActionInstallEllipsis)
			: L10n.string(.Launcher.launcherRosettaActionInstallAgain)
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
