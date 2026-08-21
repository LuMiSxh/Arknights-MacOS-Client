// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingPersonalizationView: View {
	@Bindable var model: LauncherViewModel
	let browseArtwork: () -> Void

	var body: some View {
		OnboardingPage(
			title: "Make the launcher yours",
			subtitle:
				"Artwork fills the launcher window. Dynamic Theme samples that image and carries its color into controls and compatible icon styles.",
			accentColor: model.accentColor
		) {
			OnboardingPanel(title: "Launcher artwork", systemImage: "photo.on.rectangle.angled") {
				Group {
					if let artwork = model.heroArtwork {
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
						title: "Browse Presets…", systemImage: "square.grid.2x2",
						tone: .accent(model.accentColor), presentation: .compact,
						action: browseArtwork
					)
					CapsuleActionButton(
						"Choose Image…", systemImage: "photo.badge.plus",
						tone: .accent(model.accentColor), presentation: .compact,
						action: model.chooseCustomArtwork
					)
					Spacer()
					CapsuleActionButton(
						"Use Default", systemImage: "arrow.counterclockwise",
						tone: .neutral, presentation: .compact,
						action: model.resetArtwork
					)
				}
			}

			OnboardingPanel(title: "Theme & launcher status", systemImage: "paintpalette") {
				OnboardingToggleRow(
					title: "Dynamic Theme",
					detail:
						"Matches the launcher accent, glass tint, and compatible icon styles to the selected artwork.",
					isOn: $model.usesDynamicTheme,
					accentColor: model.accentColor
				)
				SettingsHairline()
				OnboardingToggleRow(
					title: "Show Game Version",
					detail:
						"Adds the installed Arknights version and a manual update check above the Play controls.",
					isOn: $model.showsGameVersion,
					accentColor: model.accentColor
				)
				SettingsHairline()
				OnboardingToggleRow(
					title: "Server Time & Reset Countdown",
					detail:
						"Shows the active region and time remaining until that server's next daily reset.",
					isOn: $model.showsServerResetCountdown,
					accentColor: model.accentColor
				)
			}
		}
	}
}
