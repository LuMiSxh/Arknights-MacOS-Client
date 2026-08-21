// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingRosettaRecoveryView: View {
	let installationState: RosettaInstallationState
	let accentColor: Color
	let install: () -> Void
	let checkAgain: () -> Void

	@State private var confirmsInstallation = false

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			switch installationState {
			case .idle:
				recoveryIntroduction
				CapsuleActionButton(
					title: "Install Rosetta 2…", systemImage: "arrow.down.circle",
					tone: .accent(accentColor)
				) {
					confirmsInstallation = true
				}
			case .installing:
				HStack(spacing: 12) {
					ProgressView()
					Text("Installing Rosetta 2 with Apple’s software update tool…")
						.foregroundStyle(.secondary)
				}
			case .failed(let message):
				recoveryIntroduction
				Label("Installation failed", systemImage: "exclamationmark.triangle.fill")
					.foregroundStyle(.orange)
				Text(message)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
				Text("You can also install Rosetta manually in Terminal:")
					.foregroundStyle(.secondary)
				Text("softwareupdate --install-rosetta --agree-to-license")
					.font(.callout.monospaced())
					.textSelection(.enabled)
				HStack(spacing: 10) {
					CapsuleActionButton(
						title: "Try Installation Again…", systemImage: "arrow.clockwise",
						tone: .accent(accentColor)
					) {
						confirmsInstallation = true
					}
					CapsuleActionButton(
						"Check Again", systemImage: "checkmark.arrow.trianglehead.counterclockwise",
						tone: .accent(accentColor)
					) {
						checkAgain()
					}
				}
			}
		}
		.tint(accentColor)
		.confirmsRosettaInstallation(isPresented: $confirmsInstallation, install: install)
	}

	private var recoveryIntroduction: some View {
		Text(
			"Rosetta 2 is missing. Install Apple’s compatibility layer so the bundled Wine runtime can start."
		)
		.foregroundStyle(.secondary)
		.fixedSize(horizontal: false, vertical: true)
	}
}
