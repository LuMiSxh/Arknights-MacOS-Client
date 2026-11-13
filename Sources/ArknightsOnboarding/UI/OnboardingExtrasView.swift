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

	private var reminderBinding: Binding<ResetReminderAnswer?> {
		Binding(
			get: { ResetReminderAnswer(timing: preferences.resetReminderTiming) },
			set: { answer in
				guard let answer else { return }
				// The launcher asks macOS for permission and sets this back to Off if refused.
				preferences.resetReminderTiming = answer.timing
			}
		)
	}

	var body: some View {
		OnboardingPage(
			step: .extras,
			subtitle: "Update checks only notify you. Nothing downloads until you choose"
		) {
			OnboardingQuestion(
				question: "Update checks",
				answers: UpdateCheckAnswer.allCases.map(\.answer),
				selection: updateBinding
			)

			OnboardingQuestion(
				question: "Remind you before the daily reset?",
				answers: ResetReminderAnswer.allCases.map(\.answer),
				selection: reminderBinding
			)

			SettingsPanel(title: "Music") {
				OnboardingToggleRow(
					title: "Launcher music",
					detail: "YouTube playlist. Pauses while the game runs.",
					isOn: $preferences.playsLauncherMusic,
				)
			}

			OnboardingMoreOptions {
				OnboardingQuestion(
					question: "Discord presence",
					answers: DiscordPresenceAnswer.allCases.map(\.answer),
					selection: presenceBinding
				)

				if preferences.playsLauncherMusic {
					playbackPanel
				}
			}
		}
	}

	private var playbackPanel: some View {
		SettingsPanel(title: "Playback") {
			LabeledContent("Volume") {
				HStack(spacing: LauncherTokens.Spacing.control) {
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
			OnboardingToggleRow(
				title: "Now playing",
				detail: "Shows the current track and playback controls on the Home screen.",
				isOn: $preferences.showsPlayingMusic,
			)
		}
	}
}
