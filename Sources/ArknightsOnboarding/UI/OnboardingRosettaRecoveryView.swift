// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

struct OnboardingRosettaRecoveryView: View {
	static let checkAgainTitle = "Check Again"

	let installationState: RosettaInstallationState
	let failureCode: SupportCode?
	@Environment(\.launcherTheme) private var theme
	let install: () -> Void
	let checkAgain: () -> Void

	@State private var confirmsInstallation = false

	var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
			switch installationState {
			case .idle:
				recoveryIntroduction
				CapsuleActionButton(
					title: "Install Rosetta 2…",
					systemImage: "arrow.down.circle",
					tone: .accent
				) {
					confirmsInstallation = true
				}
			case .installing:
				HStack(spacing: LauncherTokens.Spacing.content) {
					ProgressView()
					Text("Installing Rosetta 2 with Apple’s software update tool…")
						.foregroundStyle(theme.textSecondary)
				}
			case .failed(let message):
				recoveryIntroduction
				InlineFailureView(message: message, code: failureCode)
				Text("You can also install Rosetta manually in Terminal:")
					.foregroundStyle(theme.textSecondary)
				Text("softwareupdate --install-rosetta --agree-to-license")
					.font(.callout.monospaced())
					.textSelection(.enabled)
				HStack(spacing: LauncherTokens.Spacing.control) {
					CapsuleActionButton(
						title: "Try Installation Again…",
						systemImage: "arrow.clockwise",
						tone: .accent
					) {
						confirmsInstallation = true
					}
					CapsuleActionButton(
						title: Self.checkAgainTitle,
						systemImage: "checkmark.arrow.trianglehead.counterclockwise",
						tone: .accent
					) {
						checkAgain()
					}
				}
			}
		}
		.tint(theme.accentFill)
		.confirmsRosettaInstallation(isPresented: $confirmsInstallation, install: install)
	}

	private var recoveryIntroduction: some View {
		Text("Install Apple’s compatibility layer so the game can start.")
			.foregroundStyle(theme.textSecondary)
			.fixedSize(horizontal: false, vertical: true)
	}
}
