// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct AudioSettingsPage: View {
	@Bindable var model: LauncherViewModel
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		SettingsPage(
			title: L10n.string(SettingsStrings.audioTitle),
			subtitle: L10n.string(SettingsStrings.audioSubtitle),
			accentColor: model.accentColor
		) {
			SettingsPanel(title: L10n.string(SettingsStrings.audioMusic), systemImage: "music.note")
			{
				SettingsActionRow(
					title: L10n.string(SettingsStrings.audioBackgroundMusic),
					detail: L10n.string(SettingsStrings.audioBackgroundMusicDetail)
				) {
					Toggle(
						L10n.string(SettingsStrings.audioBackgroundMusic),
						isOn: $model.playsLauncherMusic
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}

				if model.playsLauncherMusic {
					SettingsHairline()
					SettingsActionRow(
						title: L10n.string(SettingsStrings.audioURL),
						detail: L10n.string(SettingsStrings.audioURLDetail)
					) {
						ThemedTextField(
							L10n.string(SettingsStrings.audioURL),
							prompt: L10n.string(SettingsStrings.audioURLPrompt),
							text: $model.launcherMusicURL,
							systemImage: "link",
							accentColor: model.accentColor
						)
						.frame(width: 250)
					}
					SettingsHairline()
					SettingsActionRow(
						title: L10n.string(SettingsStrings.audioVolume),
						detail: L10n.string(SettingsStrings.audioVolumeDetail)
					) {
						HStack(spacing: 8) {
							Image(systemName: "speaker.fill")
								.font(.caption)
								.foregroundStyle(.secondary)
							Slider(value: $model.launcherMusicVolume, in: 0...1, step: 0.05)
								.tint(model.accentColor)
								.frame(width: 140)
							Image(systemName: "speaker.wave.3.fill")
								.font(.caption)
								.foregroundStyle(.secondary)
							Text(
								SettingsStrings.audioVolumePercent(
									Int(model.launcherMusicVolume * 100)
								)
							)
							.font(.caption.monospacedDigit())
							.foregroundStyle(.secondary)
							.frame(width: 36, alignment: .trailing)
						}
					}
					SettingsHairline()
					SettingsActionRow(
						title: L10n.string(SettingsStrings.audioCurrentlyPlaying),
						detail: L10n.string(SettingsStrings.audioCurrentlyPlayingDetail)
					) {
						Toggle(
							L10n.string(SettingsStrings.audioCurrentlyPlaying),
							isOn: $model.showsPlayingMusic
						)
						.labelsHidden()
						.toggleStyle(.switch)
						.tint(model.accentColor)
					}
				}
			}
			.animation(
				reduceMotion ? nil : .easeInOut(duration: 0.2),
				value: model.playsLauncherMusic
			)
		}
	}
}
