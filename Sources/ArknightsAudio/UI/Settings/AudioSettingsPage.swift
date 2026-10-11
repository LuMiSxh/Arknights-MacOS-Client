// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

package struct AudioSettingsPage: View {
	@Bindable var settings: LauncherPreferencesController
	package let accentColor: Color

	package init(settings: LauncherPreferencesController, accentColor: Color) {
		self.settings = settings
		self.accentColor = accentColor
	}

	package var body: some View {
		SettingsPage(
			title: "Audio",
			subtitle: "Music while the launcher is open",
			accentColor: accentColor
		) {
			SettingsPanel(title: "Music", systemImage: "music.note") {
				SettingsActionRow(
					title: "Play background music",
					detail: "Plays music while the launcher is open and the game is closed."
				) {
					SettingsToggle(
						"Play background music",
						isOn: $settings.playsLauncherMusic,
						accentColor: accentColor
					)
				}

				if settings.playsLauncherMusic {
					SettingsHairline()
					SettingsActionRow(
						title: "Music URL",
						detail: "A YouTube video or playlist link."
					) {
						ThemedTextField(
							"Music URL",
							prompt: "https://www.youtube.com/playlist?...",
							text: $settings.launcherMusicURL,
							systemImage: "link",
							accentColor: accentColor
						)
						.frame(width: 250)
					}
					SettingsHairline()
					SettingsActionRow(
						title: "Volume",
						detail: "How loud the launcher music plays."
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
							.accessibilityLabel("Volume")
							.accessibilityValue(
								Text(

									"\(Int(settings.launcherMusicVolume * 100))%"
								)
							)
							Image(systemName: "speaker.wave.3.fill")
								.font(.caption)
								.foregroundStyle(.secondary)
								.accessibilityHidden(true)
							Text(

								"\(Int(settings.launcherMusicVolume * 100))%"
							)
							.font(.caption.monospacedDigit())
							.foregroundStyle(.secondary)
							.frame(width: 36, alignment: .trailing)
						}
					}
					SettingsHairline()
					SettingsActionRow(
						title: "Show what's playing",
						detail: "Shows the current track and playback controls on the launcher."
					) {
						SettingsToggle(
							"Show what's playing",
							isOn: $settings.showsPlayingMusic,
							accentColor: accentColor
						)
					}
				}
			}
		}
	}
}
