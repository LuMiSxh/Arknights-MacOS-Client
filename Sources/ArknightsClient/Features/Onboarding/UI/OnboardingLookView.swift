// SPDX-License-Identifier: MPL-2.0

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
			title: OnboardingStrings.lookTitle,
			subtitle: OnboardingStrings.lookSubtitle,
			accentColor: customization.accentColor
		) {
			OnboardingQuestion(
				question: OnboardingStrings.artworkQuestion,
				systemImage: "photo.on.rectangle.angled",
				actions: [
					OnboardingAnswer(
						value: Action.defaultArtwork, title: OnboardingStrings.defaultArtwork,
						detail: OnboardingStrings.defaultArtworkDetail,
						systemImage: "arrow.counterclockwise", action: resetArtwork),
					OnboardingAnswer(
						value: .preset, title: OnboardingStrings.pickPreset,
						detail: OnboardingStrings.pickPresetDetail,
						systemImage: "square.grid.2x2", action: browseArtwork),
					OnboardingAnswer(
						value: .ownImage, title: OnboardingStrings.chooseOwnImage,
						detail: OnboardingStrings.chooseOwnImageDetail,
						systemImage: "photo.badge.plus", action: customization.chooseCustomArtwork),
				],
				accentColor: customization.accentColor
			) {
				artworkPreview
			}

			OnboardingQuestion(
				question: OnboardingStrings.colorsQuestion,
				systemImage: "paintpalette",
				answers: [true, false].map(OnboardingStrings.colorsAnswer),
				selection: colorsBinding,
				accentColor: customization.accentColor
			)

			OnboardingQuestion(
				question: OnboardingStrings.dockQuestion,
				systemImage: "dock.rectangle",
				actions: dockActions,
				accentColor: customization.accentColor
			) {
				OnboardingDockIconPreview(customization: customization)
			}

			OnboardingQuestion(
				question: OnboardingStrings.infoQuestion,
				systemImage: "rectangle.bottomthird.inset.filled",
				answers: LauncherInfoAnswer.allCases.map(OnboardingStrings.infoAnswer),
				selections: $preferences.shownLauncherInfo,
				accentColor: customization.accentColor
			)
		}
	}

	private var dockActions: [OnboardingAnswer<Action>] {
		var actions: [OnboardingAnswer<Action>] = [
			OnboardingAnswer(
				value: Action.operatorIcons, title: OnboardingStrings.chooseOperator,
				detail: OnboardingStrings.chooseOperatorDetail,
				systemImage: "person.2.crop.square.stack", action: browseOperators)
		]
		if customization.hasCustomAppIcon || customization.hasCustomGameIcon {
			actions.append(
				OnboardingAnswer(
					value: .standardIcons, title: OnboardingStrings.standardIcons,
					detail: OnboardingStrings.standardIconsDetail,
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
					.accessibilityLabel(OnboardingStrings.currentArtworkAccessibility)
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
