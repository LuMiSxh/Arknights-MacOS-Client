// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

struct OnboardingAnswer<Value: Hashable>: Identifiable {
	let value: Value
	let title: String
	var detail = ""
	let systemImage: String
	var isRecommended = false
	// Mechanism or alternate name, shown as a tooltip.
	var help: String?
	// Runs when an action card is tapped. Selection questions ignore it.
	var action: (@MainActor () -> Void)?

	var id: Value { value }
}

// Asks one setup question and applies the picked answer immediately, so players configure the
// launcher by answering instead of reading individual settings. A question picks one answer,
// several answers, or offers action cards that open a chooser.
struct OnboardingQuestion<Value: Hashable, Accessory: View>: View {
	@Environment(\.launcherTheme) private var theme
	private enum Interaction {
		case single(Binding<Value?>)
		case multiple(Binding<Set<Value>>)
		case action
	}

	let question: String
	let systemImage: String
	let answers: [OnboardingAnswer<Value>]
	private let interaction: Interaction
	let isDisabled: Bool
	let footnote: String?
	let accessory: Accessory
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	private init(
		question: String, systemImage: String, answers: [OnboardingAnswer<Value>],
		interaction: Interaction, isDisabled: Bool, footnote: String?,
		accessory: Accessory
	) {
		self.question = question
		self.systemImage = systemImage
		self.answers = answers
		self.interaction = interaction
		self.isDisabled = isDisabled
		self.footnote = footnote
		self.accessory = accessory
	}

	// Action cards, each with a chevron, that run their own closure. The accessory shows a
	// preview of the current choice above the cards.
	init(
		question: String, systemImage: String, actions: [OnboardingAnswer<Value>],
		@ViewBuilder accessory: () -> Accessory
	) {
		self.init(
			question: question, systemImage: systemImage, answers: actions, interaction: .action,
			isDisabled: false, footnote: nil, accessory: accessory())
	}

	var body: some View {
		SettingsPanel(title: question) {
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
					.foregroundStyle(theme.textSecondary)
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
		let shape = RoundedRectangle(
			cornerRadius: LauncherVisuals.Radius.control, style: .continuous)
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
					.foregroundStyle(isSelected ? theme.accentInk : theme.textSecondary)
					.frame(width: 28)
					.accessibilityHidden(true)
				VStack(alignment: .leading, spacing: 4) {
					HStack(spacing: LauncherVisuals.Spacing.control) {
						Text(answer.title)
							.font(.body.weight(.medium))
							.foregroundStyle(theme.textPrimary)
						if answer.isRecommended {
							Text("Recommended")
								.font(.caption2.weight(.medium))
								.foregroundStyle(theme.textSecondary)
								.padding(.horizontal, LauncherVisuals.Spacing.control)
								.padding(.vertical, 2)
								.overlay(Capsule().stroke(theme.hairline))
						}
					}
					if !answer.detail.isEmpty {
						Text(answer.detail)
							.font(.callout)
							.foregroundStyle(theme.textSecondary)
							.multilineTextAlignment(.leading)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
				Spacer(minLength: LauncherVisuals.Spacing.content)
				Image(systemName: trailingGlyph(isSelected: isSelected))
					.font(.title3)
					.foregroundStyle(isSelected ? theme.accentInk : theme.textSecondary)
					.accessibilityHidden(true)
			}
			.padding(LauncherVisuals.Spacing.content)
			.frame(maxWidth: .infinity, alignment: .leading)
			.contentShape(shape)
		}
		.buttonStyle(
			OnboardingAnswerStyle(isSelected: isSelected, shape: shape)
		)
		.disabled(isDisabled)
		.help(answer.help ?? "")
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}
}

extension OnboardingQuestion where Accessory == EmptyView {
	// One answer, applied the moment it is picked. The footnote adds a hint under the cards.
	init(
		question: String, systemImage: String, answers: [OnboardingAnswer<Value>],
		selection: Binding<Value?>, isDisabled: Bool = false,
		footnote: String? = nil
	) {
		self.init(
			question: question, systemImage: systemImage, answers: answers,
			interaction: .single(selection), isDisabled: isDisabled,
			footnote: footnote, accessory: EmptyView())
	}

	init(
		question: String, systemImage: String, answers: [OnboardingAnswer<Value>],
		selections: Binding<Set<Value>>
	) {
		self.init(
			question: question, systemImage: systemImage, answers: answers,
			interaction: .multiple(selections), isDisabled: false,
			footnote: nil, accessory: EmptyView())
	}
}

// Answer cards press like large shared tiles and hover by changing the surface, as settings
// controls do. A Glass surface is rebuilt when the selection tint changes, which made the release
// spring snap to full size.
private struct OnboardingAnswerStyle<S: InsettableShape>: ButtonStyle {
	let isSelected: Bool
	let shape: S

	func makeBody(configuration: Configuration) -> some View {
		OnboardingAnswerBody(configuration: configuration, isSelected: isSelected, shape: shape)
	}
}

private struct OnboardingAnswerBody<S: InsettableShape>: View {
	package let configuration: ButtonStyleConfiguration
	let isSelected: Bool
	let shape: S
	@Environment(\.isEnabled) private var isEnabled
	@Environment(\.launcherTheme) private var theme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isHovered = false

	var body: some View {
		configuration.label
			.background {
				shape.fill(isSelected ? theme.accentGlassTint : theme.controlFill)
					.overlay(shape.fill(isHovered ? theme.hoverTint : .clear))
			}
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
		guard isEnabled, !reduceMotion, configuration.isPressed else { return 1 }
		return LauncherMotion.subtlePressedScale
	}

	private var border: Color {
		isSelected ? theme.accentGlassStroke : theme.controlStroke
	}

	private func curve(_ curve: LauncherMotion.Curve) -> Animation? {
		LauncherMotion.animation(curve, reduceMotion: reduceMotion)
	}
}
