// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingGameSettingsView: View {
	@Bindable var preferences: LauncherPreferencesController
	let lifecycle: LauncherLifecycleStore
	let accentColor: Color
	@Environment(\.displayScale) private var displayScale

	var body: some View {
		OnboardingPage(
			title: OnboardingStrings.gameTitle,
			subtitle: OnboardingStrings.gameSubtitle,
			accentColor: accentColor
		) {
			OnboardingQuestion(
				question: OnboardingStrings.placementQuestion,
				systemImage: "macwindow",
				answers: GamePlacementAnswer.allCases.map(OnboardingStrings.placementAnswer),
				selection: answerBinding(\.placement),
				accentColor: accentColor,
				isDisabled: lifecycle.activity.isGameActive
			)
			OnboardingQuestion(
				question: OnboardingStrings.renderingQuestion,
				systemImage: "sparkles",
				answers: GameRenderingMode.allCases.map(OnboardingStrings.renderingAnswer),
				selection: answerBinding(\.rendering),
				accentColor: accentColor,
				isDisabled: lifecycle.activity.isGameActive
			)
			Text(displaySummary)
				.font(.callout)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
				.padding(.horizontal, LauncherVisuals.Spacing.panel)
				.onAppear(perform: applyRecommendedAnswers)

		}
	}

	private var answers: GameDisplayAnswers { GameDisplayAnswers(preferences.launchOptions) }

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

	private var displaySummary: String {
		let options = preferences.launchOptions
		let plan = GameDisplayPlan(
			options: options, backingScaleFactor: displayScale,
			fullscreenDisplay: GameFullscreenDisplay.primary)
		guard let size = plan.renderSize else { return OnboardingStrings.displaySummaryFallback }
		let window = options.displayMode == .fullscreen ? nil : options.windowSize
		return OnboardingStrings.displaySummary(
			render: SettingsStrings.renderSummary(plan, size: size, window: window))
	}

	/// Untouched defaults start from the recommended answers. Players returning with in-game
	/// display settings keep their window mode and rendering, but the launcher takes over sizing,
	/// so the answers shown are the answers in effect.
	private func applyRecommendedAnswers() {
		guard let screen = GameScreenMetrics.main else { return }
		let options = preferences.launchOptions
		if options == .default {
			preferences.launchOptions = GameDisplayAnswers.recommended.applied(
				to: options, screen: screen)
		} else if options.usesGameSettings {
			preferences.launchOptions = answers.applied(to: options, screen: screen)
		}
	}
}
