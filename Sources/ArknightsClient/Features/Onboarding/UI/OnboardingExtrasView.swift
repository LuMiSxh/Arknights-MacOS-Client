// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingExtrasView: View {
	@Bindable var preferences: LauncherPreferencesController
	let accentColor: Color

	var body: some View {
		OnboardingPage(
			title: L10n.string(OnboardingStrings.extrasTitle),
			subtitle: L10n.string(OnboardingStrings.extrasSubtitle),
			accentColor: accentColor
		) {
			SettingsPanel(
				title: L10n.string(OnboardingStrings.updatesTitle),
				systemImage: "arrow.trianglehead.2.clockwise"
			) {
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.launcherUpdateTitle),
					detail: L10n.string(OnboardingStrings.launcherUpdateDetail),
					isOn: $preferences.automaticallyChecksLauncherUpdates,
					accentColor: accentColor
				)
				SettingsHairline()
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.gameUpdateTitle),
					detail: L10n.string(OnboardingStrings.gameUpdateDetail),
					isOn: $preferences.automaticallyChecksGameUpdates,
					accentColor: accentColor
				)
				SettingsHairline()
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.announcementsTitle),
					detail: L10n.string(OnboardingStrings.announcementsDetail),
					isOn: $preferences.announcementsEnabled,
					accentColor: accentColor
				)
			}

			SettingsPanel(
				title: L10n.string(OnboardingStrings.musicTitle), systemImage: "music.note"
			) {
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.backgroundMusicTitle),
					detail: L10n.string(OnboardingStrings.backgroundMusicDetail),
					isOn: $preferences.playsLauncherMusic,
					accentColor: accentColor
				)

				if preferences.playsLauncherMusic {
					SettingsHairline()
					LabeledContent(L10n.string(OnboardingStrings.volume)) {
						HStack(spacing: 10) {
							Image(systemName: "speaker.fill")
								.foregroundStyle(.secondary)
							Slider(value: $preferences.launcherMusicVolume, in: 0...1, step: 0.05)
								.tint(accentColor)
							Text(
								preferences.launcherMusicVolume,
								format: .percent.precision(.fractionLength(0))
							)
							.font(.caption.monospacedDigit())
							.foregroundStyle(.secondary)
							.frame(width: 42, alignment: .trailing)
						}
					}
					SettingsHairline()
					OnboardingToggleRow(
						title: L10n.string(OnboardingStrings.nowPlayingTitle),
						detail: L10n.string(OnboardingStrings.nowPlayingDetail),
						isOn: $preferences.showsPlayingMusic,
						accentColor: accentColor
					)
				}
			}
		}
	}
}
