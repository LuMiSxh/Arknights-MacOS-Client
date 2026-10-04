// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// One answer the player can pick in a setup question.
struct OnboardingAnswer<Value: Hashable>: Identifiable {
	let value: Value
	let title: String
	let detail: String
	let systemImage: String
	var isRecommended = false
	/// The technical name, for example "Retina", shown as a quiet label after the title.
	var technicalName: String?
	/// Runs when an action card is tapped. Selection questions ignore it.
	var action: (@MainActor () -> Void)?

	var id: Value { value }
}

/// Asks one setup question and applies the picked answer immediately, so players configure the
/// launcher by answering instead of reading individual settings. A question picks one answer,
/// several answers, or offers action cards that open a chooser.
struct OnboardingQuestion<Value: Hashable, Accessory: View>: View {
	private enum Interaction {
		case single(Binding<Value?>)
		case multiple(Binding<Set<Value>>)
		case action
	}

	let question: String
	let systemImage: String
	let answers: [OnboardingAnswer<Value>]
	private let interaction: Interaction
	let accentColor: Color
	let isDisabled: Bool
	let footnote: String?
	let accessory: Accessory
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	private init(
		question: String, systemImage: String, answers: [OnboardingAnswer<Value>],
		interaction: Interaction, accentColor: Color, isDisabled: Bool, footnote: String?,
		accessory: Accessory
	) {
		self.question = question
		self.systemImage = systemImage
		self.answers = answers
		self.interaction = interaction
		self.accentColor = accentColor
		self.isDisabled = isDisabled
		self.footnote = footnote
		self.accessory = accessory
	}

	/// Action cards, each with a chevron, that run their own closure. The accessory shows a
	/// preview of the current choice above the cards.
	init(
		question: String, systemImage: String, actions: [OnboardingAnswer<Value>],
		accentColor: Color, @ViewBuilder accessory: () -> Accessory
	) {
		self.init(
			question: question, systemImage: systemImage, answers: actions, interaction: .action,
			accentColor: accentColor, isDisabled: false, footnote: nil, accessory: accessory())
	}

	var body: some View {
		SettingsPanel(title: question, systemImage: systemImage) {
			accessory
			VStack(spacing: LauncherVisuals.Spacing.control) {
				ForEach(answers) { answer in
					answerButton(answer)
				}
			}
			.accessibilityElement(children: .contain)
			.accessibilityLabel(question)
			if let footnote {
				Text(footnote)
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

	private func isSelected(_ answer: OnboardingAnswer<Value>) -> Bool {
		switch interaction {
		case .single(let selection): selection.wrappedValue == answer.value
		case .multiple(let selections): selections.wrappedValue.contains(answer.value)
		case .action: false
		}
	}

	private func trailingGlyph(isSelected: Bool) -> String {
		switch interaction {
		case .single: isSelected ? "checkmark.circle.fill" : "circle"
		case .multiple: isSelected ? "checkmark.square.fill" : "square"
		case .action: "chevron.forward"
		}
	}

	private func choose(_ answer: OnboardingAnswer<Value>) {
		switch interaction {
		case .single(let selection):
			selection.wrappedValue = answer.value
		case .multiple(let selections):
			if selections.wrappedValue.contains(answer.value) {
				selections.wrappedValue.remove(answer.value)
			} else {
				selections.wrappedValue.insert(answer.value)
			}
		case .action:
			answer.action?()
		}
	}

	private func answerButton(_ answer: OnboardingAnswer<Value>) -> some View {
		let isSelected = isSelected(answer)
		let shape = RoundedRectangle(cornerRadius: LauncherVisuals.Radius.row, style: .continuous)
		return Button {
			// Answers can reveal follow-up panels or change the summary, so move those too.
			withAnimation(LauncherMotion.animation(.state, reduceMotion: reduceMotion)) {
				choose(answer)
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
						if let technicalName = answer.technicalName {
							Text(technicalName)
								.font(.caption.weight(.medium))
								.foregroundStyle(.tertiary)
						}
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
				Image(systemName: trailingGlyph(isSelected: isSelected))
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

extension OnboardingQuestion where Accessory == EmptyView {
	/// One answer, applied the moment it is picked. The footnote adds a hint under the cards.
	init(
		question: String, systemImage: String, answers: [OnboardingAnswer<Value>],
		selection: Binding<Value?>, accentColor: Color, isDisabled: Bool = false,
		footnote: String? = nil
	) {
		self.init(
			question: question, systemImage: systemImage, answers: answers,
			interaction: .single(selection), accentColor: accentColor, isDisabled: isDisabled,
			footnote: footnote, accessory: EmptyView())
	}

	/// Any number of answers, each shown with a checkbox.
	init(
		question: String, systemImage: String, answers: [OnboardingAnswer<Value>],
		selections: Binding<Set<Value>>, accentColor: Color
	) {
		self.init(
			question: question, systemImage: systemImage, answers: answers,
			interaction: .multiple(selections), accentColor: accentColor, isDisabled: false,
			footnote: nil, accessory: EmptyView())
	}
}

/// Answer cards use the shared press and hover motion on a plain surface. A Glass surface is
/// rebuilt when the selection tint changes, which made the release spring snap to full size.
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
			.scaleEffect(scale)
			.onHover { isHovered = isEnabled && $0 }
			.animation(curve(.hover), value: isHovered)
			.animation(
				curve(configuration.isPressed ? .press : .release), value: configuration.isPressed
			)
			.animation(curve(.state), value: isSelected)
	}

	private var scale: CGFloat {
		guard isEnabled, !reduceMotion else { return 1 }
		if configuration.isPressed { return LauncherMotion.pressedScale }
		return isHovered ? LauncherMotion.hoverScale : 1
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
