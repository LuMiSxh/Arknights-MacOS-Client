// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct AudioSettingsPage: View {
	@Bindable var model: LauncherViewModel
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		SettingsPage(
			title: "Audio", subtitle: "Background music playback",
			accentColor: model.accentColor
		) {
			SettingsPanel(title: "Music", systemImage: "music.note") {
				SettingsActionRow(
					title: "Play Background Music",
					detail: "Plays music while the launcher is open and the game is not running."
				) {
					Toggle(
						"Play Background Music",
						isOn: $model.playsLauncherMusic
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}

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
					SettingsActionRow(
						title: "Volume",
						detail: "Sets the launcher music playback level."
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
							Text("\(Int(model.launcherMusicVolume * 100))%")
								.font(.caption.monospacedDigit())
								.foregroundStyle(.secondary)
								.frame(width: 36, alignment: .trailing)
						}
					}
					SettingsHairline()
					SettingsActionRow(
						title: "Show Currently Playing",
						detail:
							"Shows the current track and expandable playback controls above the launcher controls."
					) {
						Toggle(
							"Show Currently Playing",
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
