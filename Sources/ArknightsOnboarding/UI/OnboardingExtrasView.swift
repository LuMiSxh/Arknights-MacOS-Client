// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct OnboardingExtrasView: View {
	@Bindable var preferences: LauncherPreferencesController
	let accentColor: Color

	private var updateBinding: Binding<UpdateCheckAnswer?> {
		Binding(
			get: {
				UpdateCheckAnswer(
					launcherChecks: preferences.automaticallyChecksLauncherUpdates,
					gameChecks: preferences.automaticallyChecksGameUpdates,
					announcements: preferences.announcementsEnabled
				)
			},
			set: { answer in
				guard let answer else { return }
				preferences.automaticallyChecksLauncherUpdates = answer.checksForUpdates
				preferences.automaticallyChecksGameUpdates = answer.checksForUpdates
				preferences.announcementsEnabled = answer.showsAnnouncements
			}
		)
	}

	var body: some View {
		OnboardingPage(
			title: "Updates & Audio",
			subtitle: "Update checks only notify you. Nothing downloads until you choose.",
			accentColor: accentColor
		) {
			OnboardingQuestion(
				question: "Update checks",
				systemImage: "arrow.trianglehead.2.clockwise",
				answers: UpdateCheckAnswer.allCases.map(\.answer),
				selection: updateBinding,
				accentColor: accentColor
			)

			SettingsPanel(title: "Music", systemImage: "speaker.wave.2") {
				OnboardingToggleRow(
					title: "Launcher music",
					detail: "YouTube playlist. Pauses while the game runs.",
					isOn: $preferences.playsLauncherMusic,
					accentColor: accentColor
				)
				if preferences.playsLauncherMusic {
					SettingsHairline()
					LabeledContent("Volume") {
						HStack(spacing: 10) {
							Image(systemName: "speaker.fill")
								.foregroundStyle(.secondary)
								.accessibilityHidden(true)
							Slider(value: $preferences.launcherMusicVolume, in: 0...1, step: 0.05)
								.tint(accentColor)
								.accessibilityLabel("Volume")
							Text(
								preferences.launcherMusicVolume,
								format: .percent.precision(.fractionLength(0))
							)
							.font(.caption.monospacedDigit())
							.foregroundStyle(.secondary)
							.frame(width: 42, alignment: .trailing)
							.accessibilityHidden(true)
						}
					}
					SettingsHairline()
					OnboardingToggleRow(
						title: "Show what's playing",
						detail: "Adds the current track and playback controls to the launcher.",
						isOn: $preferences.showsPlayingMusic,
						accentColor: accentColor
					)
				}
			}
		}
	}
}
