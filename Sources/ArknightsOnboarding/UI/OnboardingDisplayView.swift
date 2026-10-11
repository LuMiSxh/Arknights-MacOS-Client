// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct OnboardingDisplayView: View {
	@Bindable var preferences: LauncherPreferencesController
	let lifecycle: LauncherLifecycleStore
	let accentColor: Color

	var body: some View {
		OnboardingPage(
			title: "How do you like to play?",
			subtitle:
				"Your answers set the game up for this screen, so there is nothing to calculate.",
			accentColor: accentColor
		) {
			OnboardingQuestion(
				question: "Where should the game appear?",
				systemImage: "macwindow",
				answers: GamePlacementAnswer.allCases.map(OnboardingStrings.placementAnswer),
				selection: answerBinding(\.placement),
				accentColor: accentColor,
				isDisabled: isLocked
			)
			if answers.placement == .window {
				OnboardingQuestion(
					question: "How big should the window be?",
					systemImage: "rectangle.expand.diagonal",
					answers: GameWindowSizeChoice.allCases.map(OnboardingStrings.windowSizeAnswer),
					selection: answerBinding(\.windowSize),
					accentColor: accentColor,
					isDisabled: isLocked,
					footnote: "You can pick an exact size in Settings any time."
				)
			}
			OnboardingQuestion(
				question: "What matters most to you?",
				systemImage: "sparkles",
				answers: GameRenderingMode.allCases.map(OnboardingStrings.renderingAnswer),
				selection: answerBinding(\.rendering),
				accentColor: accentColor,
				isDisabled: isLocked
			)
			// The runtime reports pointer support only while launching, so the question is always
			// shown; a runtime without it falls back to the game's own cursor at launch.
			OnboardingQuestion(
				question: "Which pointer should the game use?",
				systemImage: "cursorarrow.motionlines",
				answers: PointerAnswer.allCases.map(OnboardingStrings.pointerAnswer),
				selection: pointerBinding,
				accentColor: accentColor,
				isDisabled: isLocked
			)
			Text(OnboardingStrings.displaySummary(answers))
				.font(.callout)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
				.padding(.horizontal, LauncherVisuals.Spacing.panel)
				.onAppear(perform: applyRecommendedAnswers)
		}
	}

	private var isLocked: Bool { lifecycle.activity.isGameActive }

	private var answers: GameDisplayAnswers {
		GameDisplayAnswers(preferences.launchOptions, screen: GameScreenMetrics.main)
	}

	private func answerBinding<Value>(
		_ keyPath: WritableKeyPath<GameDisplayAnswers, Value>
	) -> Binding<Value?> {
		Binding(
			get: { answers[keyPath: keyPath] },
			set: { value in
				guard let value, let screen = GameScreenMetrics.main else { return }
				var updated = answers
				updated[keyPath: keyPath] = value
				preferences.launchOptions = updated.applied(
					to: preferences.launchOptions, screen: screen)
			}
		)
	}

	private var pointerBinding: Binding<PointerAnswer?> {
		Binding(
			get: { preferences.pointerAnswer },
			set: { if let answer = $0 { preferences.pointerAnswer = answer } }
		)
	}

	/// Untouched defaults start from the recommended answers. Players returning with in-game
	/// display settings keep their window mode and rendering, but the launcher takes over sizing,
	/// so the answers shown are the answers in effect. The pointer has no untouched marker, so it
	/// is only recommended alongside untouched display defaults.
	private func applyRecommendedAnswers() {
		guard let screen = GameScreenMetrics.main else { return }
		let options = preferences.launchOptions
		if options == .default {
			preferences.launchOptions = GameDisplayAnswers.recommended.applied(
				to: options, screen: screen)
			preferences.pointerAnswer = .recommended
		} else if options.usesGameSettings {
			preferences.launchOptions = answers.applied(to: options, screen: screen)
		}
	}
}
