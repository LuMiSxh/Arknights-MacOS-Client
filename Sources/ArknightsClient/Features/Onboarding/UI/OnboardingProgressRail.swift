// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingProgressRail: View {
	let currentStep: OnboardingStep
	let accentColor: Color
	let appVersion: String

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Text(OnboardingStrings.setupAssistant)
				.font(.caption.monospaced().weight(.semibold))
				.tracking(1.4)
				.foregroundStyle(.tertiary)
				.padding(.horizontal, 18)
				.padding(.top, 22)
				.padding(.bottom, 14)

			VStack(spacing: LauncherVisuals.Spacing.compact) {
				ForEach(OnboardingStep.allCases) { step in
					HStack(spacing: LauncherVisuals.Spacing.control) {
						RoundedRectangle(cornerRadius: 1)
							.fill(currentStep == step ? accentColor : .clear)
							.frame(width: 2, height: 18)
							.accessibilityHidden(true)
						Image(systemName: markerImage(for: step))
							.frame(width: 17)
							.symbolRenderingMode(.monochrome)
							.accessibilityHidden(true)
						Text(OnboardingStrings.stepTitle(step))
							.fontWeight(currentStep == step ? .semibold : .regular)
						Spacer(minLength: 0)
					}
					.foregroundStyle(foregroundStyle(for: step))
					.padding(.vertical, 8)
					.padding(.trailing, 12)
					.background(
						backgroundFill(for: step),
						in: .rect(cornerRadius: LauncherVisuals.Radius.row)
					)
					.frame(minHeight: 38)
					.accessibilityElement(children: .combine)
					.accessibilityLabel(OnboardingStrings.stepTitle(step))
					.accessibilityAddTraits(currentStep == step ? .isSelected : [])
				}
			}
			.padding(.horizontal, 10)

			Spacer()

			HStack(spacing: LauncherVisuals.Spacing.control) {
				Rectangle()
					.fill(accentColor)
					.frame(width: 28, height: 2)
				Text(OnboardingStrings.progressVersion(appVersion))
					.font(.caption.monospaced())
					.foregroundStyle(.tertiary)
			}
			.padding(18)
		}
		.frame(width: 205)
		.background(LauncherVisuals.navigationRailBackground)
	}

	private func foregroundStyle(for step: OnboardingStep) -> Color {
		if step == currentStep { return accentColor }
		if step.rawValue < currentStep.rawValue { return .primary }
		return .secondary
	}

	private func backgroundFill(for step: OnboardingStep) -> Color {
		step == currentStep ? LauncherVisuals.selectedNavigationFill(for: accentColor) : .clear
	}

	private func markerImage(for step: OnboardingStep) -> String {
		step.rawValue < currentStep.rawValue ? "checkmark" : step.systemImage
	}
}
