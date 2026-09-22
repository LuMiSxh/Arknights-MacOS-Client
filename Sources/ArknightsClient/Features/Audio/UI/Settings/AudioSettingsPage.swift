// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct AudioSettingsPage: View {
	@Bindable var settings: LauncherPreferencesController
	let accentColor: Color

	var body: some View {
		SettingsPage(
			title: SettingsStrings.audioTitle,
			subtitle: SettingsStrings.audioSubtitle,
			accentColor: accentColor
		) {
			SettingsPanel(title: SettingsStrings.audioMusic, systemImage: "music.note") {
				SettingsActionRow(
					title: SettingsStrings.audioBackgroundMusic,
					detail: SettingsStrings.audioBackgroundMusicDetail
				) {
					SettingsToggle(
						SettingsStrings.audioBackgroundMusic,
						isOn: $settings.playsLauncherMusic,
						accentColor: accentColor
					)
				}

				if settings.playsLauncherMusic {
					SettingsHairline()
					SettingsActionRow(
						title: SettingsStrings.audioURL,
						detail: SettingsStrings.audioURLDetail
					) {
						ThemedTextField(
							SettingsStrings.audioURL,
							prompt: SettingsStrings.audioURLPrompt,
							text: $settings.launcherMusicURL,
							systemImage: "link",
							accentColor: accentColor
						)
						.frame(width: 250)
					}
					SettingsHairline()
					SettingsActionRow(
						title: SettingsStrings.audioVolume,
						detail: SettingsStrings.audioVolumeDetail
					) {
						HStack(spacing: 8) {
							Image(systemName: "speaker.fill")
								.font(.caption)
								.foregroundStyle(.secondary)
								.accessibilityHidden(true)
							SettingsSlider(
								value: $settings.launcherMusicVolume,
								range: 0...1,
								step: 0.05,
								accentColor: accentColor,
								width: 140
							)
							.accessibilityLabel(SettingsStrings.audioVolume)
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
								.accessibilityHidden(true)
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
						title: SettingsStrings.audioCurrentlyPlaying,
						detail: SettingsStrings.audioCurrentlyPlayingDetail
					) {
						SettingsToggle(
							SettingsStrings.audioCurrentlyPlaying,
							isOn: $settings.showsPlayingMusic,
							accentColor: accentColor
						)
					}
				}
			}
		}
	}
}
