// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct AudioSettingsPage: View {
	@Bindable var settings: LauncherPreferencesController
	let accentColor: Color

	var body: some View {
		SettingsPage(
			title: AudioStrings.settingsTitle,
			subtitle: AudioStrings.settingsSubtitle,
			accentColor: accentColor
		) {
			SettingsPanel(title: AudioStrings.settingsMusic, systemImage: "music.note") {
				SettingsActionRow(
					title: AudioStrings.settingsBackgroundMusic,
					detail: AudioStrings.settingsBackgroundMusicDetail
				) {
					SettingsToggle(
						AudioStrings.settingsBackgroundMusic,
						isOn: $settings.playsLauncherMusic,
						accentColor: accentColor
					)
				}

				if settings.playsLauncherMusic {
					SettingsHairline()
					SettingsActionRow(
						title: AudioStrings.settingsURL,
						detail: AudioStrings.settingsURLDetail
					) {
						ThemedTextField(
							AudioStrings.settingsURL,
							prompt: AudioStrings.settingsURLPrompt,
							text: $settings.launcherMusicURL,
							systemImage: "link",
							accentColor: accentColor
						)
						.frame(width: 250)
					}
					SettingsHairline()
					SettingsActionRow(
						title: AudioStrings.settingsVolume,
						detail: AudioStrings.settingsVolumeDetail
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
							.accessibilityLabel(AudioStrings.settingsVolume)
							.accessibilityValue(
								Text(

									AudioStrings.settingsVolumePercent(
										Int(settings.launcherMusicVolume * 100)
									)
								)
							)
							Image(systemName: "speaker.wave.3.fill")
								.font(.caption)
								.foregroundStyle(.secondary)
								.accessibilityHidden(true)
							Text(

								AudioStrings.settingsVolumePercent(
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
						title: AudioStrings.settingsCurrentlyPlaying,
						detail: AudioStrings.settingsCurrentlyPlayingDetail
					) {
						SettingsToggle(
							AudioStrings.settingsCurrentlyPlaying,
							isOn: $settings.showsPlayingMusic,
							accentColor: accentColor
						)
					}
				}
			}
		}
	}
}
