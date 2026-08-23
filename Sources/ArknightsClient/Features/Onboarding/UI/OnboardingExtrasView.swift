// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingExtrasView: View {
	@Bindable var model: LauncherViewModel

	var body: some View {
		OnboardingPage(
			title: L10n.string(OnboardingStrings.extrasTitle),
			subtitle: L10n.string(OnboardingStrings.extrasSubtitle),
			accentColor: model.accentColor
		) {
			SettingsPanel(
				title: L10n.string(OnboardingStrings.updatesTitle),
				systemImage: "arrow.trianglehead.2.clockwise"
			) {
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.launcherUpdateTitle),
					detail: L10n.string(OnboardingStrings.launcherUpdateDetail),
					isOn: $model.automaticallyChecksLauncherUpdates,
					accentColor: model.accentColor
				)
				SettingsHairline()
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.gameUpdateTitle),
					detail: L10n.string(OnboardingStrings.gameUpdateDetail),
					isOn: $model.automaticallyChecksGameUpdates,
					accentColor: model.accentColor
				)
				SettingsHairline()
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.announcementsTitle),
					detail: L10n.string(OnboardingStrings.announcementsDetail),
					isOn: $model.announcementsEnabled,
					accentColor: model.accentColor
				)
			}

			SettingsPanel(
				title: L10n.string(OnboardingStrings.musicTitle), systemImage: "music.note"
			) {
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.backgroundMusicTitle),
					detail: L10n.string(OnboardingStrings.backgroundMusicDetail),
					isOn: $model.playsLauncherMusic,
					accentColor: model.accentColor
				)

				if model.playsLauncherMusic {
					SettingsHairline()
					LabeledContent(L10n.string(OnboardingStrings.volume)) {
						HStack(spacing: 10) {
							Image(systemName: "speaker.fill")
								.foregroundStyle(.secondary)
							Slider(value: $model.launcherMusicVolume, in: 0...1, step: 0.05)
								.tint(model.accentColor)
							Text(
								model.launcherMusicVolume,
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
						isOn: $model.showsPlayingMusic,
						accentColor: model.accentColor
					)
				}
			}
		}
	}
}
