// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import SwiftUI

struct IntegrationSettingsPage: View {
	@Environment(\.launcherTheme) private var theme
	@Bindable var settings: LauncherPreferencesController
	let reminders: ResetReminderController
	let screenshots: GameScreenshotController

	private static let timingOptions: [(value: ResetReminderTiming, title: String)] = [
		(.off, "Off"),
		(.atReset, "At reset"),
		(.minutes15, "15 minutes before"),
		(.minutes30, "30 minutes before"),
		(.minutes60, "1 hour before"),
		(.minutes120, "2 hours before"),
	]

	private var regionsSummary: String {
		let selected = reminders.availableRegions.filter(settings.resetReminderRegions.contains)
		switch selected.count {
		case 0: return "None"
		case 1: return selected[0].displayName
		default: return "\(selected.count) servers"
		}
	}

	private func regionBinding(_ region: GameRegion) -> Binding<Bool> {
		Binding(
			get: { settings.resetReminderRegions.contains(region) },
			set: { isOn in
				var regions = settings.resetReminderRegions.filter { $0 != region }
				if isOn { regions.append(region) }
				settings.resetReminderRegions = regions
			}
		)
	}

	var body: some View {
		SettingsPage(
			title: "Integration",
			subtitle: "Notifications, music, and Discord while the launcher is open"
		) {
			SettingsPanel(title: "Notifications") {
				SettingsActionRow(
					title: "Daily reset reminder",
					detail: "Shows a notification before the 04:00 server reset."
				) {
					GlassMenuPicker(
						selection: $settings.resetReminderTiming,
						options: Self.timingOptions
					)
					.accessibilityLabel("Daily reset reminder")
				}
				if settings.resetReminderTiming != .off {
					SettingsHairline()
					SettingsActionRow(
						title: "Servers",
						detail: "Installed servers that get a reminder."
					) {
						GlassActionMenu(title: regionsSummary, systemImage: "server.rack") {
							ForEach(reminders.availableRegions) { region in
								Toggle(region.displayName, isOn: regionBinding(region))
							}
						}
						.accessibilityLabel("Servers")
					}
				}
				if reminders.isAccessDenied {
					SettingsHairline()
					SettingsActionRow(
						title: "Notifications are off for Arknights Client."
					) {
						CapsuleActionButton(
							title: "Open System Settings",
							systemImage: "gearshape",
							tone: .neutral,
							action: reminders.openSystemNotificationSettings
						)
					}
				}
			}

			SettingsPanel(title: "Music") {
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
						HStack(spacing: LauncherTokens.Spacing.control) {
							Image(systemName: "speaker.fill")
								.font(.caption)
								.foregroundStyle(theme.textSecondary)
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
								.foregroundStyle(theme.textSecondary)
								.accessibilityHidden(true)
							Text(

								"\(Int(settings.launcherMusicVolume * 100))%"
							)
							.font(.caption.monospacedDigit())
							.foregroundStyle(theme.textSecondary)
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

			ScreenshotsSettingsPanel(
				settings: settings, screenshots: screenshots,
				openNotificationSettings: reminders.openSystemNotificationSettings)

			SettingsPanel(title: "Discord") {
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
