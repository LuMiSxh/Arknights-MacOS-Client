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

	private var musicBinding: Binding<Bool?> {
		Binding(
			get: { preferences.playsLauncherMusic },
			set: { if let plays = $0 { preferences.playsLauncherMusic = plays } }
		)
	}

	private static func musicAnswer(_ plays: Bool) -> OnboardingAnswer<Bool> {
		plays
			? OnboardingAnswer(
				value: true, title: "Yes, play music",
				detail: "Plays the launcher's YouTube music and pauses while the game runs.",
				systemImage: "music.note")
			: OnboardingAnswer(
				value: false, title: "No, keep it quiet",
				detail: "You can turn music on later in Settings.",
				systemImage: "speaker.slash")
	}

	var body: some View {
		OnboardingPage(
			title: "A few last questions",
			subtitle:
				"Looking for updates never downloads anything by itself, apart from the game files you chose to install.",
			accentColor: accentColor
		) {
			OnboardingQuestion(
				question: "How should the launcher stay up to date?",
				systemImage: "arrow.trianglehead.2.clockwise",
				answers: UpdateCheckAnswer.allCases.map(\.answer),
				selection: updateBinding,
				accentColor: accentColor
			)

			OnboardingQuestion(
				question: "Play music while the launcher is open?",
				systemImage: "music.note",
				answers: [true, false].map(Self.musicAnswer),
				selection: musicBinding,
				accentColor: accentColor
			)

			if preferences.playsLauncherMusic {
				SettingsPanel(
					title: "Music", systemImage: "speaker.wave.2"
				) {
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
