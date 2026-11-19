// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

// Only the x86_64 runtime needs Rosetta 2, so the Install step shows this panel for that runtime.
struct OnboardingRosettaPanel: View {
	let intelTranslationState: IntelTranslationState
	let rosettaInstallationState: RosettaInstallationState
	let rosettaFailureCode: SupportCode?
	let retryIntelTranslation: () -> Void
	let installRosetta: () -> Void

	var body: some View {
		SettingsPanel(title: "Rosetta 2", tone: panelTone) {
			OnboardingStatusRow(
				title: title,
				detail: detail,
				systemImage: systemImage,
				tone: panelTone
			) {
				action
			}
		}
	}

	private var panelTone: SettingsPanelTone {
		switch intelTranslationState {
		case .available: .success
		case .rosettaMissing, .gameTestModeEnabled, .unavailable, .unsupportedOS: .warning
		case .waitingForLauncherCheck, .checking: .neutral
		}
	}

	private var title: String {
		switch intelTranslationState {
		case .waitingForLauncherCheck: "Waiting to check"
		case .checking: "Checking your Mac"
		case .available: "Your Mac can run the game"
		case .rosettaMissing: "Rosetta 2 is missing"
		case .gameTestModeEnabled: "Legacy Game Test Mode is on"
		case .unavailable: "The check could not finish"
		case .unsupportedOS: "Rosetta 2 is not available"
		}
	}

	private var detail: String? {
		switch intelTranslationState {
		case .waitingForLauncherCheck: "Your Mac is checked right after the launcher update check."
		case .checking, .available, .rosettaMissing: nil
		case .gameTestModeEnabled:
			"On macOS 27 beta, Legacy Game Test Mode stops the game from running. Turn the test mode off, then restart your Mac:"
		case .unavailable:
			"The check could not finish. Restart your Mac, then check again. If it keeps failing, include the launcher log in a bug report."
		case .unsupportedOS:
			"macOS 28 and later cannot run the x86_64 runtime. Choose ARM64 (Apple Silicon) above."
		}
	}

	@ViewBuilder
	private var action: some View {
		switch intelTranslationState {
		case .rosettaMissing:
			OnboardingRosettaRecoveryView(
				installationState: rosettaInstallationState,
				failureCode: rosettaFailureCode,
				install: installRosetta,
				checkAgain: retryIntelTranslation
			)
		case .gameTestModeEnabled:
			VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
				Text("sudo game-test-tool disable")
					.font(.callout.monospaced())
					.textSelection(.enabled)
				checkAgainButton
			}
		case .unavailable:
			checkAgainButton
		case .waitingForLauncherCheck, .checking, .available, .unsupportedOS:
			EmptyView()
		}
	}

	private var checkAgainButton: some View {
		CapsuleActionButton(
			title: OnboardingRosettaRecoveryView.checkAgainTitle,
			systemImage: "arrow.clockwise",
			tone: .accent,
			action: retryIntelTranslation
		)
	}

	private var systemImage: String? {
		switch intelTranslationState {
		case .waitingForLauncherCheck: "hourglass"
		case .checking: nil
		case .available: "checkmark.circle.fill"
		case .rosettaMissing, .gameTestModeEnabled, .unavailable, .unsupportedOS:
			"exclamationmark.triangle"
		}
	}
}
