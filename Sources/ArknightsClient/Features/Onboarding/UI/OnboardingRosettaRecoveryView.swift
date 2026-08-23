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
					title: L10n.string(OnboardingStrings.installRosetta),
					systemImage: "arrow.down.circle",
					tone: .accent(accentColor)
				) {
					confirmsInstallation = true
				}
			case .installing:
				HStack(spacing: 12) {
					ProgressView()
					Text(OnboardingStrings.rosettaInstalling)
						.foregroundStyle(.secondary)
				}
			case .failed(let message):
				recoveryIntroduction
				Label(OnboardingStrings.rosettaFailed, systemImage: "exclamationmark.triangle.fill")
					.foregroundStyle(.orange)
				Text(message)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
				Text(OnboardingStrings.rosettaManualInstall)
					.foregroundStyle(.secondary)
				Text("softwareupdate --install-rosetta --agree-to-license")
					.font(.callout.monospaced())
					.textSelection(.enabled)
				HStack(spacing: 10) {
					CapsuleActionButton(
						title: L10n.string(OnboardingStrings.tryInstallationAgain),
						systemImage: "arrow.clockwise",
						tone: .accent(accentColor)
					) {
						confirmsInstallation = true
					}
					CapsuleActionButton(
						L10n.string(OnboardingStrings.checkAgain),
						systemImage: "checkmark.arrow.trianglehead.counterclockwise",
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
		Text(OnboardingStrings.rosettaIntroduction)
			.foregroundStyle(.secondary)
			.fixedSize(horizontal: false, vertical: true)
	}
}
