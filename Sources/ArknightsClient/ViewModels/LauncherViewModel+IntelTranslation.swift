// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
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
		await log.info(
			"Intel translation preflight; state=\(check.state.diagnosticName) \(check.diagnostics)"
		)
		return check.state
	}

	var intelTranslationStatusTitle: String? {
		switch intelTranslationState {
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
		switch intelTranslationState {
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
		switch intelTranslationState {
		case .rosettaMissing, .gameTestModeEnabled, .unavailable:
			true
		case .waitingForLauncherCheck, .checking, .available, .unsupportedOS:
			false
		}
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
}
