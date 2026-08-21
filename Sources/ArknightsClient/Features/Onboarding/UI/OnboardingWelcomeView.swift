// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingWelcomeView: View {
	let updateState: OnboardingUpdateState
	let intelTranslationState: IntelTranslationState
	let rosettaInstallationState: RosettaInstallationState
	let accentColor: Color
	let retry: () -> Void
	let retryIntelTranslation: () -> Void
	let installRosetta: () -> Void

	var body: some View {
		OnboardingPage(
			title: "Welcome to Arknights Client",
			subtitle:
				"We’ll check the launcher first, then configure the game and the parts you see every day. Your choices apply immediately.",
			accentColor: accentColor
		) {
			SettingsPanel(title: statusTitle, systemImage: statusImage) {
				switch updateState {
				case .checking:
					HStack(spacing: 12) {
						ProgressView()
						Text("Checking GitHub Releases before setup starts…")
							.foregroundStyle(.secondary)
					}
				case .current:
					Label(
						"This launcher is current. Setup can continue.",
						systemImage: "checkmark.circle.fill"
					)
					.foregroundStyle(accentColor)
				case .updateRequired(let release):
					VStack(alignment: .leading, spacing: 8) {
						Text("Version \(release.version) is available.")
							.bold()
						Text(
							"Install the newer launcher and open it again. Setup stays pending so instructions always match the version you are using."
						)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
					}
				case .checkFailed:
					VStack(alignment: .leading, spacing: 10) {
						Text(
							"The launcher could not reach the update source. You can continue now; automatic checks will try again later."
						)
						.foregroundStyle(.secondary)
						CapsuleActionButton(
							title: "Try Again", systemImage: "arrow.clockwise",
							tone: .accent(accentColor), action: retry
						)
					}
				}
			}

			if updateState.allowsSetup {
				SettingsPanel(title: "Intel compatibility", systemImage: translationImage) {
					switch intelTranslationState {
					case .waitingForLauncherCheck:
						Text("Intel compatibility will be checked after the launcher update check.")
							.foregroundStyle(.secondary)
					case .checking:
						HStack(spacing: 12) {
							ProgressView()
							Text("Checking whether the bundled Wine runtime can start…")
								.foregroundStyle(.secondary)
						}
					case .available:
						Label(
							"Compatibility verified. The bundled Wine runtime can start.",
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
								"macOS Legacy Game Test Mode disables Rosetta, which the bundled Wine runtime requires. Disable the test mode, then restart your Mac:"
							)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
							Text("sudo game-test-tool disable")
								.font(.callout.monospaced())
								.textSelection(.enabled)
							CapsuleActionButton(
								"Check Again", systemImage: "arrow.clockwise",
								tone: .accent(accentColor),
								action: retryIntelTranslation
							)
						}
					case .unavailable:
						VStack(alignment: .leading, spacing: 10) {
							Text(
								"macOS could not start an Intel test process. Restart your Mac, then check again. If the problem remains, include the launcher log in a bug report."
							)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
							CapsuleActionButton(
								"Check Again", systemImage: "arrow.clockwise",
								tone: .accent(accentColor),
								action: retryIntelTranslation
							)
						}
					case .unsupportedOS:
						Text(
							"This macOS version no longer provides the general Intel translation required by the bundled Wine runtime."
						)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
					}
				}
			}

			SettingsPanel(
				title: "What happens next", systemImage: "point.forward.to.point.capsulepath"
			) {
				Text(
					"Choose a server region, begin the official PC-client download, tune display settings, and personalize the launcher. The download keeps running while you continue."
				)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
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
