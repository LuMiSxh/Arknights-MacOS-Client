// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingWelcomeView: View {
	let updateState: OnboardingUpdateState
	let rosettaState: OnboardingRosettaState
	let accentColor: Color
	let retry: () -> Void
	let retryRosetta: () -> Void

	var body: some View {
		OnboardingPage(
			title: "Welcome to Arknights Client",
			subtitle:
				"We’ll check the launcher first, then configure the game and the parts you see every day. Your choices apply immediately.",
			accentColor: accentColor
		) {
			OnboardingPanel(title: statusTitle, systemImage: statusImage) {
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
						Button("Try Again", systemImage: "arrow.clockwise", action: retry)
					}
				}
			}

			if updateState.allowsSetup {
				OnboardingPanel(title: "Rosetta 2", systemImage: rosettaImage) {
					switch rosettaState {
					case .pending:
						Text("Rosetta 2 will be checked after the launcher update check.")
							.foregroundStyle(.secondary)
					case .available:
						Label(
							"Rosetta 2 is installed. The bundled Wine runtime can start.",
							systemImage: "checkmark.circle.fill"
						)
						.foregroundStyle(accentColor)
					case .missing:
						VStack(alignment: .leading, spacing: 10) {
							Text(
								"Rosetta 2 is required to run Arknights through Wine. Open Terminal and run:"
							)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
							Text("softwareupdate --install-rosetta --agree-to-license")
								.font(.callout.monospaced())
								.textSelection(.enabled)
							Button(
								"Check Again", systemImage: "arrow.clockwise",
								action: retryRosetta
							)
						}
					}
				}
			}

			OnboardingPanel(
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

	private var rosettaImage: String {
		switch rosettaState {
		case .pending: "hourglass"
		case .available: "cpu"
		case .missing: "exclamationmark.triangle"
		}
	}
}
