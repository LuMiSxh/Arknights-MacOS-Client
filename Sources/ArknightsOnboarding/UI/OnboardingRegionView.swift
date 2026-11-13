// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

struct OnboardingRegionView: View {
	@Bindable var preferences: LauncherPreferencesController
	@Bindable var installation: InstallationController
	@Environment(\.launcherTheme) private var theme
	let canSwitchRegion: Bool
	let selectRegion: @MainActor @Sendable (GameRegion) -> Void

	private static func regionAnswer(_ region: GameRegion) -> OnboardingAnswer<GameRegion> {
		OnboardingAnswer(
			value: region, title: region.displayName,
			detail: region == .chinaBilibili ? "For Bilibili accounts." : "", systemImage: "globe")
	}

	var body: some View {
		OnboardingPage(
			step: .region,
			subtitle: "Each server has its own game files and accounts"
		) {
			OnboardingQuestion(
				question: "Server",
				answers: preferences.regionAccess.selectableRegions.map(
					Self.regionAnswer),
				selection: regionBinding,
				isDisabled: !canSwitchRegion
			)

			Text(
				"Each server is run by its publisher, which handles sign-in and purchases. Some servers use ACE Anti-Cheat, which may block or flag the game on a Mac."
			)
			.font(.callout)
			.foregroundStyle(theme.textSecondary)
			.fixedSize(horizontal: false, vertical: true)
			.padding(.horizontal, LauncherTokens.Spacing.panel)
		}
	}

	private var regionBinding: Binding<GameRegion?> {
		Binding(
			get: { installation.region },
			set: { region in
				if let region { selectRegion(region) }
			}
		)
	}
}
