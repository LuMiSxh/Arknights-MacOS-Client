// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct OnboardingWelcomeView: View {
	let updateState: OnboardingUpdateState
	let intelTranslationState: IntelTranslationState
	let requiredSchema: Int?
	let rosettaInstallationState: RosettaInstallationState
	let retry: () -> Void
	let retryIntelTranslation: () -> Void
	let installRosetta: () -> Void

	var body: some View {
		OnboardingPage(
			title: requiredSchema == nil
				? "Welcome to Arknights Client" : "Something important changed",
			subtitle: requiredSchema == nil
				? "Setup checks your Mac, then sets your server, display and launcher options. Changes apply immediately"
				: "This version of the launcher needs you to go through setup once more. Your current settings are kept as the starting point"
		) {
			if let requiredSchema {
				SettingsPanel(
					title: "Why setup is required",
					tone: .warning
				) {
					Text(Self.requiredSetupReason(schema: requiredSchema))
						.fixedSize(horizontal: false, vertical: true)
				}
			}

			SettingsPanel(title: "Launcher update") {
				OnboardingStatusRow(
					title: statusTitle,
					detail: updateDetail,
					systemImage: statusImage,
					tone: updatePanelTone
				) {
					updateAction
				}
			}

			if updateState.allowsSetup {
				SettingsPanel(title: "Your Mac") {
					OnboardingStatusRow(
						title: translationTitle,
						detail: translationDetail,
						systemImage: translationImage,
						tone: compatibilityPanelTone
					) {
						translationAction
					}
				}
			}
		}
	}

	private var statusTitle: String {
		switch updateState {
		case .checking: "Checking for launcher updates"
		case .current: "Ready for setup"
		case .updateRequired: "Update before setup"
		case .checkFailed: "Update check unavailable"
		}
	}

	static func requiredSetupReason(schema: Int) -> String {
		switch schema {
		case 2:
			"Display settings work differently in this version. Confirm display mode, rendering and cursor once."
		case 3:
			"This version adds light mode and Home controls, reorganizes settings, and changes fullscreen. Go through each step once to review your setup."
		default:
			"The launcher changed how an important setting works. Go through each step once so everything keeps working."
		}
	}

	private var updatePanelTone: SettingsPanelTone {
		switch updateState {
		case .current: .success
		case .updateRequired, .checkFailed: .warning
		case .checking: .neutral
		}
	}

	private var compatibilityPanelTone: SettingsPanelTone {
		switch intelTranslationState {
		case .available: .success
		case .rosettaMissing, .gameTestModeEnabled, .unavailable, .unsupportedOS: .warning
		case .waitingForLauncherCheck, .checking: .neutral
		}
	}

	private var updateDetail: String? {
		switch updateState {
		case .checking: nil
		case .current: "This launcher is up to date. Setup can continue."
		case .updateRequired(let version):
			"Version \(version) is available. Install the newer launcher and open it again. Setup waits so its instructions match the version you use."
		case .checkFailed:
			"The launcher could not look for updates. You can continue now; it will try again later."
		}
	}

	@ViewBuilder
	private var updateAction: some View {
		switch updateState {
		case .checkFailed:
			CapsuleActionButton(
				title: "Try Again",
				systemImage: "arrow.clockwise",
				tone: .accent,
				action: retry
			)
		case .checking, .current, .updateRequired:
			EmptyView()
		}
	}

	private var translationTitle: String {
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

	private var translationDetail: String? {
		switch intelTranslationState {
		case .waitingForLauncherCheck: "Your Mac is checked right after the launcher update check."
		case .checking, .available, .rosettaMissing: nil
		case .gameTestModeEnabled:
			"On macOS 27 beta, Legacy Game Test Mode stops the game from running. Turn the test mode off, then restart your Mac:"
		case .unavailable:
			"The check could not finish. Restart your Mac, then check again. If it keeps failing, include the launcher log in a bug report."
		case .unsupportedOS:
			"macOS 28 and later cannot run the x86_64 runtime. Choose ARM64 (Apple Silicon) in the Runtime step, then quit and reopen the launcher."
		}
	}

	@ViewBuilder
	private var translationAction: some View {
		switch intelTranslationState {
		case .rosettaMissing:
			OnboardingRosettaRecoveryView(
				installationState: rosettaInstallationState,
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

	private var statusImage: String? {
		switch updateState {
		case .checking: nil
		case .current: "checkmark.shield"
		case .updateRequired: "arrow.down.app"
		case .checkFailed: "wifi.exclamationmark"
		}
	}

	private var translationImage: String? {
		switch intelTranslationState {
		case .waitingForLauncherCheck: "hourglass"
		case .checking: nil
		case .available: "checkmark.circle.fill"
		case .rosettaMissing, .gameTestModeEnabled, .unavailable, .unsupportedOS:
			"exclamationmark.triangle"
		}
	}
}
