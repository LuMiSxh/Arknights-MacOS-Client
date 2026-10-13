// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import SwiftUI

struct OnboardingLookView: View {
	/// Names the action cards of the artwork and Dock questions so each card has a stable identity.
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
			subtitle: "Artwork, colors and Dock icon.",
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
				],
				accentColor: customization.accentColor
			) {
				artworkPreview
			}

			OnboardingQuestion(
				question: "Which colors should the launcher use?",
				systemImage: "paintpalette",
				answers: [true, false].map(Self.colorsAnswer),
				selection: colorsBinding,
				accentColor: customization.accentColor
			)

			OnboardingQuestion(
				question: "Which operator should your Dock show?",
				systemImage: "dock.rectangle",
				actions: dockActions,
				accentColor: customization.accentColor
			) {
				OnboardingDockIconPreview(customization: customization)
			}

			OnboardingQuestion(
				question: "What should the launcher show?",
				systemImage: "rectangle.bottomthird.inset.filled",
				answers: LauncherInfoAnswer.allCases.map(\.answer),
				selections: $preferences.shownLauncherInfo,
				accentColor: customization.accentColor
			)
		}
	}

	private static func colorsAnswer(_ matchesArtwork: Bool) -> OnboardingAnswer<Bool> {
		matchesArtwork
			? OnboardingAnswer(
				value: true, title: "Match the artwork",
				detail: "Buttons and glass pick up the colors of your artwork.",
				systemImage: "paintpalette", isRecommended: true)
			: OnboardingAnswer(
				value: false, title: "Keep it neutral",
				detail: "Uses the standard launcher colors whatever the artwork.",
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

	private var colorsBinding: Binding<Bool?> {
		Binding(
			get: { preferences.usesDynamicTheme },
			set: { if let matches = $0 { preferences.usesDynamicTheme = matches } }
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
					Color.black.opacity(0.35)
					Image(systemName: "photo")
						.font(.largeTitle)
						.foregroundStyle(.tertiary)
						.accessibilityHidden(true)
				}
			}
		}
		.frame(maxWidth: .infinity)
		.frame(height: 132)
		.clipped()
		.clipShape(.rect(cornerRadius: 14))
		.overlay {
			RoundedRectangle(cornerRadius: 14)
				.strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
		}
	}
}
