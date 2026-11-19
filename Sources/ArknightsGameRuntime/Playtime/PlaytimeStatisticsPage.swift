// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

package struct PlaytimeStatisticsPage: View {
	@Environment(\.launcherTheme) private var theme
	let controller: PlaytimeStatisticsController
	let regions: [GameRegion]
	@State private var confirmsReset = false

	package init(
		controller: PlaytimeStatisticsController, regions: [GameRegion]
	) {
		self.controller = controller
		self.regions = regions
	}

	private var resetIsEmpty: Bool {
		controller.totalDuration == 0
			&& controller.statistics.activeSession == nil
	}

	private var resetDetail: String {
		if resetIsEmpty {
			return "Play the game to collect statistics first."
		}
		return "Deletes all local totals and daily data. This cannot be undone."
	}

	package var body: some View {
		SettingsPage(
			title: "Playtime",
			subtitle: "How long the game has been running on this Mac"
		) {
			SettingsPanel(
				title: "Overview"
			) {
				HStack(spacing: 0) {
					metric(
						"All time",
						duration: controller.totalDuration
					)
					metricDivider
					metric(
						"7 days",
						duration: controller.duration(inLast: 7)
					)
					metricDivider
					metric(
						"30 days",
						duration: controller.duration(inLast: 30)
					)
				}
				SettingsHairline()
				latestSession
			}

			if !regions.isEmpty {
				SettingsPanel(
					title: "Servers"
				) {
					ForEach(Array(regions.enumerated()), id: \.element.id) {
						index, region in
						if index > 0 { SettingsHairline() }
						regionRow(region)
					}
				}
			}

			SettingsPanel(
				title: "About playtime"
			) {
				explanation(
					title: "What counts",
					detail:
						"Time starts when the game window becomes visible and ends with the game process. Menus, pauses, and idle time are included.",
					systemImage: "clock.badge.checkmark"
				)
				SettingsHairline()
				explanation(
					title: "Local only",
					detail:
						"Statistics stay on this Mac. They are not associated with an account, synced, or sent anywhere.",
					systemImage: "lock"
				)
			}

			DangerZonePanel {
				SettingsActionRow(
					title: "Playtime statistics",
					detail: resetDetail
				) {
					CapsuleActionButton(
						title: "Reset Statistics…",
						tone: .danger,
						presentation: .compact,
						role: .destructive
					) {
						confirmsReset = true
					}
					.disabled(resetIsEmpty)
					.confirmationDialog(
						"Reset playtime statistics?",
						isPresented: $confirmsReset,
						titleVisibility: .visible
					) {
						Button(
							"Reset Statistics",
							role: .destructive,
							action: controller.reset
						)
						Button("Cancel", role: .cancel) {}
					} message: {
						Text("Deletes all local totals and daily data. This cannot be undone.")
					}
				}
			}
		}
	}

	private var locale: Locale {
		Locale(identifier: "en_US_POSIX")
	}

	private var metricDivider: some View {
		Rectangle()
			.fill(theme.hairline)
			.frame(width: 1, height: 42)
			.padding(.horizontal, LauncherTokens.Spacing.panel)
	}

	private var latestSession: some View {
		Group {
			if let session = controller.statistics.latestSession {
				SettingsActionRow(
					title: "Latest session",
					detail:
						"\(session.region.displayName) · \(dateText(session.startedAt))"
				) {
					Text(durationText(session.duration))
						.font(.callout.monospacedDigit().weight(.semibold))
				}
			} else {
				SettingsActionRow(
					title: "Latest session",
					detail: "No completed session yet"
				) {
					EmptyView()
				}
			}
		}
	}

	private func metric(_ title: String, duration: TimeInterval) -> some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.compact) {
			Text(durationText(duration))
				.font(.title3.monospacedDigit().weight(.semibold))
			Text(title)
				.font(.caption)
				.foregroundStyle(theme.textSecondary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 10)
	}

	private func explanation(title: String, detail: String, systemImage: String) -> some View {
		HStack(alignment: .top, spacing: LauncherTokens.Spacing.content) {
			Image(systemName: systemImage)
				.frame(width: 24)
				.foregroundStyle(theme.textSecondary)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: LauncherTokens.Spacing.compact) {
				Text(title)
					.frame(maxWidth: .infinity, alignment: .leading)
				Text(detail)
					.font(.caption)
					.foregroundStyle(theme.textSecondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

	private func regionRow(_ region: GameRegion) -> some View {
		HStack(spacing: LauncherTokens.Spacing.control) {
			Image(systemName: "globe")
				.font(.caption)
				.foregroundStyle(theme.textSecondary)
				.frame(width: 18)
				.accessibilityHidden(true)
			Text(region.displayName)
			Spacer(minLength: LauncherTokens.Spacing.control)
			Text(durationText(controller.duration(for: region)))
				.font(.callout.monospacedDigit().weight(.semibold))
		}
	}

	private func durationText(_ duration: TimeInterval) -> String {
		guard duration > 0 else {
			return Duration.seconds(0).formatted(
				.units(allowed: [.minutes], width: .abbreviated)
					.locale(locale)
			)
		}
		guard duration >= 60 else { return "< 1 min" }
		return Duration.seconds(duration).formatted(
			.units(
				allowed: [.hours, .minutes],
				width: .abbreviated,
				maximumUnitCount: 2
			)
			.locale(locale)
		)
	}

	private func dateText(_ date: Date) -> String {
		date.formatted(
			.dateTime
				.day()
				.month(.abbreviated)
				.year()
				.hour()
				.minute()
				.locale(locale)
		)
	}
}
