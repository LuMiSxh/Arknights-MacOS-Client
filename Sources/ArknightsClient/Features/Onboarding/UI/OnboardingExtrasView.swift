// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingExtrasView: View {
	@Bindable var model: LauncherViewModel

	var body: some View {
		OnboardingPage(
			title: "Keep things current and comfortable",
			subtitle:
				"Automatic checks only look for new versions. Downloads still begin when you choose them, except for the installation already started by this setup.",
			accentColor: model.accentColor
		) {
			SettingsPanel(
				title: "Updates & project notices", systemImage: "arrow.trianglehead.2.clockwise"
			) {
				OnboardingToggleRow(
					title: "Check for Launcher Updates",
					detail:
						"Looks for a new launcher release when the app opens. You still choose when to download it.",
					isOn: $model.automaticallyChecksLauncherUpdates,
					accentColor: model.accentColor
				)
				SettingsHairline()
				OnboardingToggleRow(
					title: "Check for Game Updates",
					detail:
						"Compares your installed files with Yostar's current version and offers Update when needed.",
					isOn: $model.automaticallyChecksGameUpdates,
					accentColor: model.accentColor
				)
				SettingsHairline()
				OnboardingToggleRow(
					title: "Show Project Announcements",
					detail:
						"Shows important launcher notices, such as compatibility guidance, once per launch.",
					isOn: $model.announcementsEnabled,
					accentColor: model.accentColor
				)
			}

			SettingsPanel(title: "Launcher music", systemImage: "music.note") {
				OnboardingToggleRow(
					title: "Play Background Music",
					detail:
						"Plays the configured YouTube music while the launcher is open and the game is not running.",
					isOn: $model.playsLauncherMusic,
					accentColor: model.accentColor
				)

				if model.playsLauncherMusic {
					SettingsHairline()
					LabeledContent("Volume") {
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
						title: "Show Currently Playing",
						detail:
							"Adds the current track and expandable playback controls to the main launcher.",
						isOn: $model.showsPlayingMusic,
						accentColor: model.accentColor
					)
				}
			}
		}
	}
}
