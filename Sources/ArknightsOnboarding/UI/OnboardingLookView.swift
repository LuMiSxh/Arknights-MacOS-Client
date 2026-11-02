// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import SwiftUI

struct OnboardingLookView: View {
	@Environment(\.launcherTheme) private var theme
	// Names the action cards of the artwork and Dock questions so each card has a stable identity.
	private enum Action: Hashable {
		case defaultArtwork, preset, ownImage, operatorIcons, standardIcons
	}

	let customization: CustomizationController
	@Bindable var preferences: LauncherPreferencesController
	let resetArtwork: @MainActor () -> Void
	let browseArtwork: @MainActor () -> Void
	let browseOperators: @MainActor () -> Void

	var body: some View {
		OnboardingPage(
			title: "How should the launcher look?",
			subtitle: "Artwork, theme, Home controls, branding, appearance, and Dock icons",
			accentColor: customization.accentColor
		) {
			OnboardingQuestion(
				question: "Which artwork should fill the launcher?",
				systemImage: "photo.on.rectangle.angled",
				actions: [
					OnboardingAnswer(
						value: Action.defaultArtwork, title: "Default artwork",
						detail: "Official artwork for your server.",
						systemImage: "arrow.counterclockwise", action: resetArtwork),
					OnboardingAnswer(
						value: .preset, title: "Pick a preset…",
						detail: "Browse ready-made artwork.",
						systemImage: "square.grid.2x2", action: browseArtwork),
					OnboardingAnswer(
						value: .ownImage, title: "Choose Image…",
						systemImage: "photo.badge.plus", action: customization.chooseCustomArtwork),
				]
			) {
				artworkPreview
			}

			OnboardingQuestion(
				question: "Dynamic Theme",
				systemImage: "paintpalette",
				answers: [true, false].map(Self.colorsAnswer),
				selection: answerBinding(\.usesDynamicTheme)
			)

			OnboardingQuestion(
				question: "Home controls",
				systemImage: "rectangle.3.group",
				answers: HomeTheme.allCases.map(\.answer),
				selection: answerBinding(\.homeTheme),
				footnote:
					"Sub-pills, music, and the settings button. Automatic follows the artwork."
			)

			OnboardingQuestion(
				question: "Branding",
				systemImage: "textformat",
				answers: HomeTheme.allCases.map(\.brandingAnswer),
				selection: answerBinding(\.brandingTheme),
				footnote: "Logo and backdrop in the top left corner."
			)

			OnboardingQuestion(
				question: "Appearance",
				systemImage: "circle.lefthalf.filled",
				answers: LauncherAppearance.allCases.map(\.answer),
				selection: answerBinding(\.launcherAppearance),
				footnote: "Settings, setup, and dialogs. Home keeps its own controls."
			)

			OnboardingQuestion(
				question: "What should the launcher show?",
				systemImage: "rectangle.bottomthird.inset.filled",
				answers: LauncherInfoAnswer.allCases.map(\.answer),
				selections: $preferences.shownLauncherInfo
			)

			OnboardingQuestion(
				question: "Which operator should your Dock show?",
				systemImage: "dock.rectangle",
				actions: dockActions
			) {
				OnboardingDockIconPreview(customization: customization)
			}
		}
	}

	private static func colorsAnswer(_ matchesArtwork: Bool) -> OnboardingAnswer<Bool> {
		matchesArtwork
			? OnboardingAnswer(
				value: true, title: "Follow the artwork",
				detail:
					"The launcher accent and the generated Dock icons use the colors of the current artwork.",
				systemImage: "paintpalette", isRecommended: true)
			: OnboardingAnswer(
				value: false, title: "Keep it neutral",
				detail: "The launcher keeps its standard colors whatever the artwork.",
				systemImage: "circle.lefthalf.filled")
	}

	private var dockActions: [OnboardingAnswer<Action>] {
		var actions: [OnboardingAnswer<Action>] = [
			OnboardingAnswer(
				value: Action.operatorIcons, title: "Choose Operator…",
				detail: "Gives the launcher and the game a matching Dock icon.",
				systemImage: "person.2.crop.square.stack", action: browseOperators)
		]
		if customization.hasCustomAppIcon || customization.hasCustomGameIcon {
			actions.append(
				OnboardingAnswer(
					value: .standardIcons, title: "Use Default",
					detail: "Launcher and game Dock icons.",
					systemImage: "arrow.counterclockwise",
					action: customization.resetOperatorIcons))
		}
		return actions
	}

	// Maps a single-choice preference to the optional binding that OnboardingQuestion expects.
	private func answerBinding<Value>(
		_ keyPath: ReferenceWritableKeyPath<LauncherPreferencesController, Value>
	) -> Binding<Value?> {
		Binding(
			get: { preferences[keyPath: keyPath] },
			set: { if let value = $0 { preferences[keyPath: keyPath] = value } }
		)
	}

	private var artworkPreview: some View {
		Group {
			if let artwork = customization.heroArtwork {
				Image(nsImage: artwork)
					.resizable()
					.scaledToFill()
					.accessibilityLabel("Current launcher artwork")
			} else {
				ZStack {
					theme.controlFill
					Image(systemName: "photo")
						.font(.title2)
						.foregroundStyle(theme.textTertiary)
						.accessibilityHidden(true)
				}
			}
		}
		.frame(maxWidth: .infinity)
		.frame(height: 132)
		.clipped()
		.clipShape(.rect(cornerRadius: LauncherVisuals.Radius.panel))
		.overlay {
			RoundedRectangle(cornerRadius: LauncherVisuals.Radius.panel)
				.strokeBorder(theme.hairline, lineWidth: 1)
		}
	}
}
