// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingExtrasView: View {
	@Bindable var preferences: LauncherPreferencesController
	let accentColor: Color

	var body: some View {
		OnboardingPage(
			title: OnboardingStrings.extrasTitle,
			subtitle: OnboardingStrings.extrasSubtitle,
			accentColor: accentColor
		) {
			SettingsPanel(
				title: OnboardingStrings.updatesTitle,
				systemImage: "arrow.trianglehead.2.clockwise"
			) {
				OnboardingToggleRow(
					title: OnboardingStrings.launcherUpdateTitle,
					detail: OnboardingStrings.launcherUpdateDetail,
					isOn: $preferences.automaticallyChecksLauncherUpdates,
					accentColor: accentColor
				)
				SettingsHairline()
				OnboardingToggleRow(
					title: OnboardingStrings.gameUpdateTitle,
					detail: OnboardingStrings.gameUpdateDetail,
					isOn: $preferences.automaticallyChecksGameUpdates,
					accentColor: accentColor
				)
				SettingsHairline()
				OnboardingToggleRow(
					title: OnboardingStrings.announcementsTitle,
					detail: OnboardingStrings.announcementsDetail,
					isOn: $preferences.announcementsEnabled,
					accentColor: accentColor
				)
			}

			SettingsPanel(
				title: OnboardingStrings.musicTitle, systemImage: "music.note"
			) {
				OnboardingToggleRow(
					title: OnboardingStrings.backgroundMusicTitle,
					detail: OnboardingStrings.backgroundMusicDetail,
					isOn: $preferences.playsLauncherMusic,
					accentColor: accentColor
				)

				if preferences.playsLauncherMusic {
					SettingsHairline()
					LabeledContent(OnboardingStrings.volume) {
						HStack(spacing: 10) {
							Image(systemName: "speaker.fill")
								.foregroundStyle(.secondary)
								.accessibilityHidden(true)
							Slider(value: $preferences.launcherMusicVolume, in: 0...1, step: 0.05)
								.tint(accentColor)
								.accessibilityLabel(OnboardingStrings.volume)
							Text(
								preferences.launcherMusicVolume,
								format: .percent.precision(.fractionLength(0))
							)
							.font(.caption.monospacedDigit())
							.foregroundStyle(.secondary)
							.frame(width: 42, alignment: .trailing)
							.accessibilityHidden(true)
						}
					}
					SettingsHairline()
					OnboardingToggleRow(
						title: OnboardingStrings.nowPlayingTitle,
						detail: OnboardingStrings.nowPlayingDetail,
						isOn: $preferences.showsPlayingMusic,
						accentColor: accentColor
					)
				}
			}
		}
	}
}
