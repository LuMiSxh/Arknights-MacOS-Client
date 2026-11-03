// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct OnboardingExtrasView: View {
	@Environment(\.launcherTheme) private var theme
	@Bindable var preferences: LauncherPreferencesController

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

	private var presenceBinding: Binding<DiscordPresenceAnswer?> {
		Binding(
			get: { preferences.discordPresenceAnswer },
			set: { answer in
				guard let answer else { return }
				preferences.discordPresenceAnswer = answer
			}
		)
	}

	var body: some View {
		OnboardingPage(
			title: "Updates & Integrations",
			subtitle: "Update checks only notify you. Nothing downloads until you choose"
		) {
			OnboardingQuestion(
				question: "Update checks",
				systemImage: "arrow.trianglehead.2.clockwise",
				answers: UpdateCheckAnswer.allCases.map(\.answer),
				selection: updateBinding
			)

			OnboardingQuestion(
				question: "Discord presence",
				systemImage: "gamecontroller",
				answers: DiscordPresenceAnswer.allCases.map(\.answer),
				selection: presenceBinding
			)

			SettingsPanel(title: "Music") {
				OnboardingToggleRow(
					title: "Launcher music",
					detail: "YouTube playlist. Pauses while the game runs.",
					isOn: $preferences.playsLauncherMusic,
				)
				if preferences.playsLauncherMusic {
					SettingsHairline()
					LabeledContent("Volume") {
						HStack(spacing: LauncherVisuals.Spacing.control) {
							Image(systemName: "speaker.fill")
								.foregroundStyle(theme.textSecondary)
								.accessibilityHidden(true)
							Slider(value: $preferences.launcherMusicVolume, in: 0...1, step: 0.05)
								.tint(theme.accentFill)
								.accessibilityLabel("Volume")
							Text(
								preferences.launcherMusicVolume,
								format: .percent.precision(.fractionLength(0))
							)
							.font(.caption.monospacedDigit())
							.foregroundStyle(theme.textSecondary)
							.frame(minWidth: 44, alignment: .trailing)
							.accessibilityHidden(true)
						}
					}
					SettingsHairline()
					OnboardingToggleRow(
						title: "Show what’s playing",
						detail: "Adds the current track and playback controls to the launcher.",
						isOn: $preferences.showsPlayingMusic,
					)
				}
			}
		}
	}
}
