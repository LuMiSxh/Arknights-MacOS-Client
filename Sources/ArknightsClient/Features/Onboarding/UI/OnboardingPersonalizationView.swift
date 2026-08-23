// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingPersonalizationView: View {
	@Bindable var model: LauncherViewModel
	let browseArtwork: () -> Void

	var body: some View {
		OnboardingPage(
			title: L10n.string(OnboardingStrings.personalizationTitle),
			subtitle: L10n.string(OnboardingStrings.personalizationSubtitle),
			accentColor: model.accentColor
		) {
			SettingsPanel(
				title: L10n.string(OnboardingStrings.artwork),
				systemImage: "photo.on.rectangle.angled"
			) {
				Group {
					if let artwork = model.heroArtwork {
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

				HStack {
					CapsuleActionButton(
						title: L10n.string(OnboardingStrings.browsePresets),
						systemImage: "square.grid.2x2",
						tone: .accent(model.accentColor), presentation: .compact,
						action: browseArtwork
					)
					CapsuleActionButton(
						L10n.string(OnboardingStrings.chooseImage), systemImage: "photo.badge.plus",
						tone: .accent(model.accentColor), presentation: .compact,
						action: model.chooseCustomArtwork
					)
					Spacer()
					CapsuleActionButton(
						L10n.string(OnboardingStrings.useDefault),
						systemImage: "arrow.counterclockwise",
						tone: .neutral, presentation: .compact,
						action: model.resetArtwork
					)
				}
			}

			SettingsPanel(
				title: L10n.string(OnboardingStrings.themeStatusPanel), systemImage: "paintpalette"
			) {
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.dynamicTheme),
					detail: L10n.string(OnboardingStrings.dynamicThemeDetail),
					isOn: $model.usesDynamicTheme,
					accentColor: model.accentColor
				)
				SettingsHairline()
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.gameVersion),
					detail: L10n.string(OnboardingStrings.gameVersionDetail),
					isOn: $model.showsGameVersion,
					accentColor: model.accentColor
				)
				SettingsHairline()
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.resetCountdown),
					detail: L10n.string(OnboardingStrings.resetCountdownDetail),
					isOn: $model.showsServerResetCountdown,
					accentColor: model.accentColor
				)
			}
		}
	}
}
