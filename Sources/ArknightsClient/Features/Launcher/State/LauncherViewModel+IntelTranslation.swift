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
					"Apple’s installer exited with status \(result.status). Use the Terminal command below or check the launcher log for details."
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
			let message =
				"Apple’s Rosetta installer could not start. Use the Terminal command below or check the launcher log for details."
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
		if rosettaInstallationState.isInstalling { return "Installing Rosetta 2…" }
		if rosettaInstallationState.failureMessage != nil {
			return "Rosetta installation failed"
		}
		return switch intelTranslationState {
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

	var intelTranslationStatusDetail: String? {
		if rosettaInstallationState.isInstalling {
			return "Apple’s software update tool is installing the Intel compatibility layer."
		}
		if let failure = rosettaInstallationState.failureMessage { return failure }
		return switch intelTranslationState {
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
			? "Install Rosetta 2…" : "Try Installation Again…"
	}

	var playHelp: String {
		intelTranslationStatusDetail ?? "Start Arknights"
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
