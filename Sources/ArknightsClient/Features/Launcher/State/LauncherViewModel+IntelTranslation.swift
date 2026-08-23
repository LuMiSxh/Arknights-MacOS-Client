// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	@discardableResult
	func installRosetta() async -> IntelTranslationState {
		guard intelTranslationState == .rosettaMissing else { return intelTranslationState }

		#if DEBUG
			if developerScenario == .onboardingRosetta {
				rosettaInstallationState = .installing
				try? await Task.sleep(for: .seconds(2))
				rosettaInstallationState = .idle
				intelTranslationState = .available
				return .available
			}
		#endif

		rosettaInstallationState = .installing
		let task: Task<IntelTranslationProcessResult, any Error>
		if let existing = rosettaInstallationTask {
			task = existing
		} else {
			task = Task { [installRosettaSystemSoftware] in
				try await installRosettaSystemSoftware()
			}
			rosettaInstallationTask = task
		}

		do {
			let result = try await task.value
			rosettaInstallationTask = nil
			let output = Self.boundedProcessOutput(result.output)
			await log.info(
				"Rosetta installation finished; status=\(result.status) output=\(output)"
			)
			guard result.status == 0 else {
				rosettaInstallationState = .failed(
					L10n.string(
						.Launcher.launcherRosettaFailureInstallerExited(String(result.status)))
				)
				return intelTranslationState
			}
			rosettaInstallationState = .idle
			return await refreshIntelTranslationAvailability(force: true)
		} catch is CancellationError {
			rosettaInstallationTask = nil
			rosettaInstallationState = .idle
			return intelTranslationState
		} catch {
			rosettaInstallationTask = nil
			let message = L10n.string(.Launcher.launcherRosettaFailureInstallerStart)
			rosettaInstallationState = .failed(message)
			await log.error("Rosetta installation failed: \(error.localizedDescription)")
			return intelTranslationState
		}
	}

	@discardableResult
	func refreshIntelTranslationAvailability(force: Bool = false) async
		-> IntelTranslationState
	{
		if !force,
			intelTranslationState != .checking,
			intelTranslationState != .waitingForLauncherCheck
		{
			return intelTranslationState
		}

		intelTranslationState = .checking
		let task: Task<IntelTranslationCheck, Never>
		if let existing = intelTranslationCheckTask {
			task = existing
		} else {
			task = Task { [checkIntelTranslation] in
				await checkIntelTranslation()
			}
			intelTranslationCheckTask = task
		}

		let check = await task.value
		intelTranslationCheckTask = nil
		intelTranslationState = check.state
		if check.state != .rosettaMissing {
			rosettaInstallationState = .idle
		}
		await log.info(
			"Intel translation preflight; state=\(check.state.diagnosticName) \(check.diagnostics)"
		)
		return check.state
	}

	var intelTranslationStatusTitle: String? {
		if rosettaInstallationState.isInstalling {
			return L10n.string(.Launcher.launcherRosettaStatusInstalling)
		}
		if rosettaInstallationState.failureMessage != nil {
			return L10n.string(.Launcher.launcherRosettaStatusInstallationFailed)
		}
		return switch intelTranslationState {
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

	var intelTranslationStatusDetail: String? {
		if rosettaInstallationState.isInstalling {
			return L10n.string(.Launcher.launcherRosettaDetailInstalling)
		}
		if let failure = rosettaInstallationState.failureMessage { return failure }
		return switch intelTranslationState {
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

	var canRetryIntelTranslationCheck: Bool {
		guard !rosettaInstallationState.isInstalling else { return false }
		return switch intelTranslationState {
		case .rosettaMissing, .gameTestModeEnabled, .unavailable:
			true
		case .waitingForLauncherCheck, .checking, .available, .unsupportedOS:
			false
		}
	}

	var canInstallRosetta: Bool {
		intelTranslationState == .rosettaMissing && !rosettaInstallationState.isInstalling
	}

	var rosettaInstallationActionTitle: String {
		rosettaInstallationState.failureMessage == nil
			? L10n.string(.Launcher.launcherRosettaActionInstallEllipsis)
			: L10n.string(.Launcher.launcherRosettaActionInstallAgain)
	}

	var intelTranslationLaunchError: LauncherError {
		switch intelTranslationState {
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

	private static func boundedProcessOutput(_ output: String) -> String {
		let normalized = output.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !normalized.isEmpty else { return "empty" }
		return String(normalized.prefix(AppConstants.IO.processDiagnosticMaximumCharacters))
	}
}
