// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct OnboardingWelcomeView: View {
	let accentColor: Color
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
				? "Setup checks your Mac, then sets your server, display and launcher options. Changes apply immediately."
				: "This version of the launcher needs you to go through setup once more. Your current settings are kept as the starting point.",
			accentColor: accentColor
		) {
			if let requiredSchema {
				SettingsPanel(
					title: "Why setup is required",
					systemImage: "exclamationmark.triangle",
					tone: .warning
				) {
					Text(Self.requiredSetupReason(schema: requiredSchema))
						.fixedSize(horizontal: false, vertical: true)
				}
			}

			SettingsPanel(title: statusTitle, systemImage: statusImage, tone: updatePanelTone) {
				switch updateState {
				case .checking:
					HStack(spacing: 12) {
						ProgressView()
						Text(OnboardingUpdateState.checkingTitle)
							.foregroundStyle(.secondary)
					}
				case .current:
					Label(
						"This launcher is up to date. Setup can continue.",
						systemImage: "checkmark.circle.fill"
					)
					.foregroundStyle(accentColor)
				case .updateRequired(let version):
					VStack(alignment: .leading, spacing: 8) {
						Text("Version \(version) is available.")
							.bold()
						Text(
							"Install the newer launcher and open it again. Setup waits so its instructions match the version you use."
						)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
					}
				case .checkFailed:
					VStack(alignment: .leading, spacing: 10) {
						Text(
							"The launcher could not look for updates. You can continue now; it will try again later."
						)
						.foregroundStyle(.secondary)
						CapsuleActionButton(
							title: "Try Again",
							systemImage: "arrow.clockwise",
							tone: .accent(accentColor), action: retry
						)
					}
				}
			}

			if updateState.allowsSetup {
				SettingsPanel(
					title: "Your Mac",
					systemImage: translationImage,
					tone: compatibilityPanelTone
				) {
					switch intelTranslationState {
					case .waitingForLauncherCheck:
						Text("Your Mac is checked right after the launcher update check.")
							.foregroundStyle(.secondary)
					case .checking:
						HStack(spacing: 12) {
							ProgressView()
							Text("Checking that your Mac can run the game…")
								.foregroundStyle(.secondary)
						}
					case .available:
						Label(
							"Your Mac can run the game.",
							systemImage: "checkmark.circle.fill"
						)
						.foregroundStyle(accentColor)
					case .rosettaMissing:
						OnboardingRosettaRecoveryView(
							installationState: rosettaInstallationState,
							accentColor: accentColor,
							install: installRosetta,
							checkAgain: retryIntelTranslation
						)
					case .gameTestModeEnabled:
						VStack(alignment: .leading, spacing: 10) {
							Text(
								"On macOS 27 beta, Legacy Game Test Mode stops the game from running. Turn the test mode off, then restart your Mac:"
							)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
							Text("sudo game-test-tool disable")
								.font(.callout.monospaced())
								.textSelection(.enabled)
							CapsuleActionButton(
								title: OnboardingRosettaRecoveryView.checkAgainTitle,
								systemImage: "arrow.clockwise",
								tone: .accent(accentColor),
								action: retryIntelTranslation
							)
						}
					case .unavailable:
						VStack(alignment: .leading, spacing: 10) {
							Text(
								"The check could not finish. Restart your Mac, then check again. If it keeps failing, include the launcher log in a bug report."
							)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
							CapsuleActionButton(
								title: OnboardingRosettaRecoveryView.checkAgainTitle,
								systemImage: "arrow.clockwise",
								tone: .accent(accentColor),
								action: retryIntelTranslation
							)
						}
					case .unsupportedOS:
						Text("This version of macOS can no longer run the game.")
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
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
			"This version reorganizes settings and changes fullscreen. Go through each step once to review your setup."
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

	private var statusImage: String {
		switch updateState {
		case .checking: "arrow.trianglehead.2.clockwise"
		case .current: "checkmark.shield"
		case .updateRequired: "arrow.down.app"
		case .checkFailed: "wifi.exclamationmark"
		}
	}

	private var translationImage: String {
		switch intelTranslationState {
		case .waitingForLauncherCheck, .checking: "hourglass"
		case .available: "cpu"
		case .rosettaMissing, .gameTestModeEnabled, .unavailable, .unsupportedOS:
			"exclamationmark.triangle"
		}
	}
}
