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
					SettingsToggle(
						L10n.string(SettingsStrings.audioBackgroundMusic),
						isOn: $settings.playsLauncherMusic,
						accentColor: accentColor
					)
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
							SettingsSlider(
								value: $settings.launcherMusicVolume,
								range: 0...1,
								step: 0.05,
								accentColor: accentColor,
								width: 140
							)
							.accessibilityLabel(L10n.string(SettingsStrings.audioVolume))
							.accessibilityValue(
								Text(
									SettingsStrings.audioVolumePercent(
										Int(settings.launcherMusicVolume * 100)
									)
								)
							)
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
						SettingsToggle(
							L10n.string(SettingsStrings.audioCurrentlyPlaying),
							isOn: $settings.showsPlayingMusic,
							accentColor: accentColor
						)
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
