// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

/// The game-files row on the finish step. It reads `installation.progress` itself, so the
/// ~10 Hz download ticks redraw this row and not the whole finish page.
struct OnboardingFinishGameStatus: View {
	let installation: InstallationController
	let title: String
	let systemImage: String
	let detail: String
	let failure: LauncherFailurePresentation?
	let install: () -> Void
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		OnboardingStatusRow(
			title: title, detail: detail, systemImage: systemImage,
			tone: failure == nil ? .neutral : .warning
		) {
			if let failure {
				InlineFailureView(message: failure.message, code: failure.code)
			}

			if installation.isDownloading, let progress = installation.progress {
				ProgressView(value: progress.fraction)
					.tint(theme.accentFill)
			}

			if !installation.isInstalled && !installation.isDownloading
				&& installation.canInstall
			{
				CapsuleActionButton(
					title: "Resume Download",
					systemImage: "arrow.clockwise",
					tone: .accent,
					action: install
				)
			}
		}
	}
}
