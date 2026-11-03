// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

/// The content of the game-status panel on the finish step. It reads `installation.progress`
/// itself, so the ~10 Hz download ticks redraw this content and not the whole finish page.
struct OnboardingFinishGameStatus: View {
	let installation: InstallationController
	let detail: String
	let accentColor: Color
	let install: () -> Void
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text(detail)
				.foregroundStyle(theme.textSecondary)
				.fixedSize(horizontal: false, vertical: true)

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
					tone: .accent(accentColor),
					action: install
				)
			}
		}
	}
}
