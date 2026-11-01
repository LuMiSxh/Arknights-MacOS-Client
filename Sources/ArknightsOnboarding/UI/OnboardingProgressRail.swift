// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct OnboardingProgressRail: View {
	@Environment(\.launcherPalette) private var palette
	let currentStep: OnboardingStep
	let accentColor: Color
	let appVersion: String

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			NavigationRailCaption(text: "Setup assistant")
				.padding(.horizontal, LauncherVisuals.Spacing.panel)
				.padding(.top, LauncherVisuals.Spacing.page)
				.padding(.bottom, LauncherVisuals.Spacing.content)

			VStack(spacing: LauncherVisuals.Spacing.compact) {
				ForEach(OnboardingStep.allCases) { step in
					NavigationRailRow(
						title: step.title,
						systemImage: markerImage(for: step),
						isSelected: currentStep == step,
						accentColor: accentColor,
						isHighlighted: step.rawValue < currentStep.rawValue
					)
				}
			}
			.padding(.horizontal, LauncherVisuals.Spacing.control)

			Spacer()

			HStack(spacing: LauncherVisuals.Spacing.control) {
				Rectangle()
					.fill(accentColor)
					.frame(width: 28, height: 2)
				Text("Version \(appVersion)")
					.font(.caption)
					.foregroundStyle(.tertiary)
			}
			.padding(LauncherVisuals.Spacing.panel)
		}
		.frame(width: LauncherVisuals.Layout.railWidth)
		.background(palette.navigationRailBackground)
	}

	private func markerImage(for step: OnboardingStep) -> String {
		step.rawValue < currentStep.rawValue ? "checkmark" : step.systemImage
	}
}
