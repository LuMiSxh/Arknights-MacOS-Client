// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct IntegrationSettingsPage: View {
	@Bindable var settings: LauncherPreferencesController
	let accentColor: Color

	var body: some View {
		SettingsPage(
			title: "Integration",
			subtitle: "Music and Discord while the launcher is open",
			accentColor: accentColor
		) {
			SettingsPanel(title: "Music", systemImage: "music.note") {
				SettingsActionRow(
					title: "Launcher music",
					detail: "YouTube playlist. Pauses while the game runs."
				) {
					SettingsToggle(
						"Launcher music",
						isOn: $settings.playsLauncherMusic,
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
							prompt: "YouTube link",
							text: $settings.launcherMusicURL,
							systemImage: "link",
						)
						.frame(minWidth: 220, idealWidth: 252, maxWidth: 280)
					}
					SettingsHairline()
					SettingsActionRow(
						title: "Volume"
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
							.frame(minWidth: 36, alignment: .trailing)
						}
					}
					SettingsHairline()
					SettingsActionRow(
						title: "Show what’s playing",
						detail: "Shows the current track and playback controls on the launcher."
					) {
						SettingsToggle(
							"Show what’s playing",
							isOn: $settings.showsPlayingMusic,
						)
					}
				}
			}

			SettingsPanel(title: "Discord", systemImage: "gamecontroller") {
				SettingsActionRow(
					title: "Discord presence",
					detail:
						"Shows the game name, your server, and the session time on your Discord profile while the game runs."
				) {
					SettingsToggle(
						"Discord presence",
						isOn: $settings.showsDiscordPresence,
					)
				}
			}
		}
	}
}
