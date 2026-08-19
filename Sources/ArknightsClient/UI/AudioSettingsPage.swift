// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct AudioSettingsPage: View {
	@Bindable var model: LauncherViewModel

	var body: some View {
		SettingsPage(
			title: "Audio", subtitle: "Background music playback",
			accentColor: model.accentColor
		) {
			SettingsPanel(title: "Music", systemImage: "music.note") {
				LabeledContent("Play Background Music") {
					Toggle(
						"Play Background Music",
						isOn: $model.playsLauncherMusic
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}
				.help("Plays music while the launcher is open and the game is not running")

				if model.playsLauncherMusic {
					SettingsHairline()
					SettingsActionRow(
						title: "Music URL",
						detail: "YouTube video or playlist link."
					) {
						TextField(
							"https://www.youtube.com/playlist?...",
							text: $model.launcherMusicURL
						)
						.textFieldStyle(.roundedBorder)
						.frame(width: 250)
					}
					SettingsHairline()
					LabeledContent("Volume") {
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
							Text("\(Int(model.launcherMusicVolume * 100))%")
								.font(.caption.monospacedDigit())
								.foregroundStyle(.secondary)
								.frame(width: 36, alignment: .trailing)
						}
					}
					SettingsHairline()
					LabeledContent("Show Currently Playing") {
						Toggle(
							"Show Currently Playing",
							isOn: $model.showsPlayingMusic
						)
						.labelsHidden()
						.toggleStyle(.switch)
						.tint(model.accentColor)
					}
					.help("Shows the title of the current track next to the version indicator")
				}
			}
		}
	}
}
