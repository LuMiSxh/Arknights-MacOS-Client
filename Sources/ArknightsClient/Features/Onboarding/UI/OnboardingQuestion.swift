// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// One answer the player can pick in a setup question.
struct OnboardingAnswer<Value: Hashable>: Identifiable {
	let value: Value
	let title: String
	let detail: String
	let systemImage: String
	var isRecommended = false

	var id: Value { value }
}

/// Asks one setup question and applies the picked answer immediately, so players configure the
/// launcher by answering instead of reading individual settings.
struct OnboardingQuestion<Value: Hashable>: View {
	let question: String
	let systemImage: String
	let answers: [OnboardingAnswer<Value>]
	@Binding var selection: Value?
	let accentColor: Color
	var isDisabled = false
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		SettingsPanel(title: question, systemImage: systemImage) {
			VStack(spacing: LauncherVisuals.Spacing.control) {
				ForEach(answers) { answer in
					answerButton(answer)
				}
			}
			.accessibilityElement(children: .contain)
			.accessibilityLabel(question)
		}
	}

	private func answerButton(_ answer: OnboardingAnswer<Value>) -> some View {
		let isSelected = selection == answer.value
		let shape = RoundedRectangle(cornerRadius: LauncherVisuals.Radius.row, style: .continuous)
		return Button {
			// Answers can reveal follow-up panels or change the summary, so move those too.
			withAnimation(LauncherMotion.animation(.state, reduceMotion: reduceMotion)) {
				selection = answer.value
			}
		} label: {
			HStack(alignment: .center, spacing: LauncherVisuals.Spacing.content) {
				Image(systemName: answer.systemImage)
					.font(.title3)
					.symbolRenderingMode(.hierarchical)
					.foregroundStyle(isSelected ? accentColor : .secondary)
					.frame(width: 28)
					.accessibilityHidden(true)
				VStack(alignment: .leading, spacing: 3) {
					HStack(spacing: LauncherVisuals.Spacing.tight) {
						Text(answer.title)
							.font(.body.weight(.semibold))
							.foregroundStyle(.primary)
						if answer.isRecommended {
							Text(OnboardingStrings.recommended)
								.font(.caption2.weight(.semibold))
								.foregroundStyle(.secondary)
								.padding(.horizontal, LauncherVisuals.Spacing.tight)
								.padding(.vertical, 1)
								.overlay(Capsule().stroke(LauncherVisuals.hairline))
						}
					}
					Text(answer.detail)
						.font(.callout)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.leading)
						.fixedSize(horizontal: false, vertical: true)
				}
				Spacer(minLength: LauncherVisuals.Spacing.content)
				Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
					.font(.title3)
					.foregroundStyle(isSelected ? accentColor : .secondary)
					.accessibilityHidden(true)
			}
			.padding(LauncherVisuals.Spacing.content)
			.frame(maxWidth: .infinity, alignment: .leading)
			.contentShape(shape)
		}
		.buttonStyle(
			OnboardingAnswerStyle(isSelected: isSelected, accentColor: accentColor, shape: shape)
		)
		.disabled(isDisabled)
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}
}

/// Answer cards span the page, so they only blend colors on hover, press, and selection:
/// scaling a surface this wide reads as a jump rather than a press.
private struct OnboardingAnswerStyle<S: InsettableShape>: ButtonStyle {
	let isSelected: Bool
	let accentColor: Color
	let shape: S

	func makeBody(configuration: Configuration) -> some View {
		OnboardingAnswerBody(
			configuration: configuration, isSelected: isSelected, accentColor: accentColor,
			shape: shape)
	}
}

private struct OnboardingAnswerBody<S: InsettableShape>: View {
	let configuration: ButtonStyleConfiguration
	let isSelected: Bool
	let accentColor: Color
	let shape: S
	@Environment(\.isEnabled) private var isEnabled
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isHovered = false

	var body: some View {
		configuration.label
			.background(shape.fill(fill))
			.overlay(shape.strokeBorder(border, lineWidth: LauncherVisuals.Control.borderWidth))
			.opacity(isEnabled ? 1 : LauncherVisuals.Control.disabledForegroundOpacity)
			.onHover { isHovered = isEnabled && $0 }
			.animation(curve(.hover), value: isHovered)
			.animation(
				curve(configuration.isPressed ? .press : .release), value: configuration.isPressed
			)
			.animation(curve(.state), value: isSelected)
	}

	private var fill: Color {
		let control = LauncherVisuals.Control.self
		var opacity =
			isSelected
			? control.enabledChromaticSurfaceOpacity : control.enabledNeutralSurfaceOpacity
		if isHovered { opacity += control.hudHoverSurfaceOpacity }
		if configuration.isPressed { opacity += control.hudHoverSurfaceOpacity }
		return (isSelected ? accentColor : Color.white).opacity(opacity)
	}

	private var border: Color {
		isSelected
			? accentColor.opacity(LauncherVisuals.Control.enabledChromaticBorderOpacity)
			: Color.white.opacity(LauncherVisuals.Control.enabledNeutralBorderOpacity)
	}

	private func curve(_ curve: LauncherMotion.Curve) -> Animation? {
		LauncherMotion.animation(curve, reduceMotion: reduceMotion)
	}
}
