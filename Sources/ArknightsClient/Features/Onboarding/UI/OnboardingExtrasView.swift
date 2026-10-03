// SPDX-License-Identifier: MPL-2.0

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

	var body: some View {
		OnboardingPage(
			title: OnboardingStrings.extrasTitle,
			subtitle: OnboardingStrings.extrasSubtitle,
			accentColor: accentColor
		) {
			OnboardingQuestion(
				question: OnboardingStrings.updatesQuestion,
				systemImage: "arrow.trianglehead.2.clockwise",
				answers: UpdateCheckAnswer.allCases.map(OnboardingStrings.updateAnswer),
				selection: updateBinding,
				accentColor: accentColor
			)

			OnboardingQuestion(
				question: OnboardingStrings.musicQuestion,
				systemImage: "music.note",
				answers: [true, false].map(OnboardingStrings.musicAnswer),
				selection: musicBinding,
				accentColor: accentColor
			)

			if preferences.playsLauncherMusic {
				SettingsPanel(
					title: OnboardingStrings.musicTitle, systemImage: "speaker.wave.2"
				) {
					LabeledContent(OnboardingStrings.volume) {
						HStack(spacing: 10) {
							Image(systemName: "speaker.fill")
								.foregroundStyle(.secondary)
								.accessibilityHidden(true)
							Slider(value: $preferences.launcherMusicVolume, in: 0...1, step: 0.05)
								.tint(accentColor)
								.accessibilityLabel(OnboardingStrings.volume)
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
						title: OnboardingStrings.nowPlayingTitle,
						detail: OnboardingStrings.nowPlayingDetail,
						isOn: $preferences.showsPlayingMusic,
						accentColor: accentColor
					)
				}
			}
		}
	}
}
