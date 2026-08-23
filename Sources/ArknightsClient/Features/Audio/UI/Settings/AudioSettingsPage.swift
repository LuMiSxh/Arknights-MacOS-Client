// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct AudioSettingsPage: View {
	@Bindable var settings: LauncherPreferencesController
	let accentColor: Color
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		SettingsPage(
			title: L10n.string(SettingsStrings.audioTitle),
			subtitle: L10n.string(SettingsStrings.audioSubtitle),
			accentColor: accentColor
		) {
			SettingsPanel(title: L10n.string(SettingsStrings.audioMusic), systemImage: "music.note")
			{
				SettingsActionRow(
					title: L10n.string(SettingsStrings.audioBackgroundMusic),
					detail: L10n.string(SettingsStrings.audioBackgroundMusicDetail)
				) {
					Toggle(
						L10n.string(SettingsStrings.audioBackgroundMusic),
						isOn: $settings.playsLauncherMusic
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(accentColor)
				}

				if settings.playsLauncherMusic {
					SettingsHairline()
					SettingsActionRow(
						title: L10n.string(SettingsStrings.audioURL),
						detail: L10n.string(SettingsStrings.audioURLDetail)
					) {
						ThemedTextField(
							L10n.string(SettingsStrings.audioURL),
							prompt: L10n.string(SettingsStrings.audioURLPrompt),
							text: $settings.launcherMusicURL,
							systemImage: "link",
							accentColor: accentColor
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
							Slider(value: $settings.launcherMusicVolume, in: 0...1, step: 0.05)
								.tint(accentColor)
								.frame(width: 140)
							Image(systemName: "speaker.wave.3.fill")
								.font(.caption)
								.foregroundStyle(.secondary)
							Text(
								SettingsStrings.audioVolumePercent(
									Int(settings.launcherMusicVolume * 100)
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
							isOn: $settings.showsPlayingMusic
						)
						.labelsHidden()
						.toggleStyle(.switch)
						.tint(accentColor)
					}
				}
			}
			.animation(
				reduceMotion ? nil : .easeInOut(duration: 0.2),
				value: settings.playsLauncherMusic
			)
		}
	}
}
