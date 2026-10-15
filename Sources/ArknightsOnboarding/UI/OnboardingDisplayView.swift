// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct OnboardingDisplayView: View {
	@Bindable var preferences: LauncherPreferencesController
	let lifecycle: LauncherLifecycleStore
	let accentColor: Color

	var body: some View {
		OnboardingPage(
			title: "Display",
			subtitle: "The launcher sets the resolution for this screen.",
			accentColor: accentColor
		) {
			OnboardingQuestion(
				question: "Display mode",
				systemImage: "macwindow",
				answers: GamePlacementAnswer.allCases.map(\.answer),
				selection: answerBinding(\.placement),
				accentColor: accentColor,
				isDisabled: isLocked
			)
			if answers.placement == .window {
				OnboardingQuestion(
					question: "Window size",
					systemImage: "rectangle.expand.diagonal",
					answers: GameWindowSizeChoice.allCases.map {
						$0.answer(on: GameScreenMetrics.main)
					},
					selection: answerBinding(\.windowSize),
					accentColor: accentColor,
					isDisabled: isLocked
				)
			}
			OnboardingQuestion(
				question: "Rendering",
				systemImage: "sparkles",
				answers: GameRenderingMode.allCases.map(\.answer),
				selection: answerBinding(\.rendering),
				accentColor: accentColor,
				isDisabled: isLocked
			)
			// The runtime reports pointer support only while launching, so the question is always
			// shown; a runtime without it falls back to the game's own cursor at launch.
			OnboardingQuestion(
				question: "Cursor",
				systemImage: "cursorarrow.motionlines",
				answers: PointerAnswer.allCases.map(\.answer),
				selection: pointerBinding,
				accentColor: accentColor,
				isDisabled: isLocked
			)
			Text(displaySummary)
				.font(.callout)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
				.padding(.horizontal, LauncherVisuals.Spacing.panel)
				.onAppear(perform: applyRecommendedAnswers)
		}
	}

	private var isLocked: Bool { lifecycle.activity.isGameActive }

	private var displaySummary: String {
		let placement =
			switch (answers.placement, answers.windowSize) {
			case (.window, .fillScreen): "Windowed, fill screen"
			case (.window, .leaveRoom): "Windowed, compact"
			case (.fullscreen, _): "Fullscreen"
			}
		let rendering =
			switch answers.rendering {
			case .retina: "Retina"
			case .metalFX: "MetalFX"
			case .standard: "Standard"
			}
		return "\(placement), \(rendering). Change this in Settings → Game."
	}

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
