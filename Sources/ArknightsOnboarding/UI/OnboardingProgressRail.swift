// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct OnboardingProgressRail: View {
	@Environment(\.launcherTheme) private var theme
	let currentStep: OnboardingStep
	let appVersion: String

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			NavigationRailCaption(text: "Setup assistant")
				.padding(.horizontal, LauncherTokens.Spacing.panel)
				.padding(.top, LauncherTokens.Spacing.page)
				.padding(.bottom, LauncherTokens.Spacing.content)

			VStack(spacing: LauncherTokens.Spacing.compact) {
				ForEach(OnboardingStep.allCases) { step in
					NavigationRailRow(
						title: step.title,
						systemImage: markerImage(for: step),
						isSelected: currentStep == step
					)
				}
			}
			.padding(.horizontal, LauncherTokens.Spacing.control)

			Spacer()

			HStack(spacing: LauncherTokens.Spacing.control) {
				Rectangle()
					.fill(theme.accentFill)
					.frame(width: 28, height: 2)
				Text("Version \(appVersion)")
					.font(.caption)
					.foregroundStyle(theme.textTertiary)
			}
			.padding(LauncherTokens.Spacing.panel)
		}
		.frame(width: LauncherTokens.Layout.railWidth)
		.background(theme.footerFill)
	}

	private func markerImage(for step: OnboardingStep) -> String {
		guard let current = OnboardingStep.allCases.firstIndex(of: currentStep),
			let index = OnboardingStep.allCases.firstIndex(of: step)
		else { return step.systemImage }
		return index < current ? "checkmark" : step.systemImage
	}
}
