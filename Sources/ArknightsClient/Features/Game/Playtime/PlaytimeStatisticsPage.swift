// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct PlaytimeStatisticsPage: View {
	let controller: PlaytimeStatisticsController
	let regions: [GameRegion]
	let accentColor: Color
	@State private var confirmsReset = false

	var body: some View {
		SettingsPage(
			title: PlaytimeStrings.title,
			subtitle: PlaytimeStrings.subtitle,
			accentColor: accentColor
		) {
			SettingsPanel(
				title: PlaytimeStrings.overview,
				systemImage: "clock"
			) {
				HStack(spacing: 0) {
					metric(
						PlaytimeStrings.total,
						duration: controller.totalDuration
					)
					metricDivider
					metric(
						PlaytimeStrings.sevenDays,
						duration: controller.duration(inLast: 7)
					)
					metricDivider
					metric(
						PlaytimeStrings.thirtyDays,
						duration: controller.duration(inLast: 30)
					)
				}
				SettingsHairline()
				latestSession
			}

			SettingsPanel(
				title: PlaytimeStrings.regions,
				systemImage: "globe"
			) {
				ForEach(Array(regions.enumerated()), id: \.element.id) {
					index, region in
					if index > 0 { SettingsHairline() }
					regionRow(region)
				}
			}

			SettingsPanel(
				title: PlaytimeStrings.about,
				systemImage: "info.circle"
			) {
				explanation(
					title: PlaytimeStrings.measurement,
					detail: PlaytimeStrings.measurementDetail,
					systemImage: "clock.badge.checkmark"
				)
				SettingsHairline()
				explanation(
					title: PlaytimeStrings.privacy,
					detail: PlaytimeStrings.privacyDetail,
					systemImage: "lock"
				)
			}

			DangerZonePanel {
				SettingsActionRow(
					title: PlaytimeStrings.reset,
					detail: PlaytimeStrings.resetDetail
				) {
					CapsuleActionButton(
						title: PlaytimeStrings.resetAction,
						systemImage: "trash",
						tone: .danger,
						presentation: .compact,
						role: .destructive
					) {
						confirmsReset = true
					}
					.disabled(
						controller.totalDuration == 0
							&& controller.statistics.activeSession == nil
					)
					.confirmationDialog(
						PlaytimeStrings.resetConfirmation,
						isPresented: $confirmsReset,
						titleVisibility: .visible
					) {
						Button(
							PlaytimeStrings.resetConfirm,
							role: .destructive,
							action: controller.reset
						)
						Button(SettingsStrings.cancel, role: .cancel) {}
					} message: {
						Text(PlaytimeStrings.resetDetail)
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
			.fill(LauncherVisuals.hairline)
			.frame(width: 1, height: 42)
			.padding(.horizontal, 18)
	}

	private var latestSession: some View {
		Group {
			if let session = controller.statistics.latestSession {
				SettingsActionRow(
					title: PlaytimeStrings.latest,
					detail:
						"\(session.region.displayName) · \(dateText(session.startedAt))"
				) {
					Text(durationText(session.duration))
						.font(.callout.monospacedDigit().weight(.semibold))
				}
			} else {
				SettingsActionRow(
					title: PlaytimeStrings.latest,
					detail: PlaytimeStrings.noSessions
				) {
					EmptyView()
				}
			}
		}
	}

	private func metric(_ title: String, duration: TimeInterval) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(durationText(duration))
				.font(.title3.monospacedDigit().weight(.semibold))
			Text(title)
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private func explanation(title: String, detail: String, systemImage: String) -> some View {
		HStack(alignment: .top, spacing: 12) {
			Image(systemName: systemImage)
				.frame(width: 18)
				.foregroundStyle(.secondary)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.compact) {
				Text(title)
				Text(detail)
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.padding(.vertical, LauncherVisuals.Spacing.control)
	}

	private func regionRow(_ region: GameRegion) -> some View {
		HStack(spacing: LauncherVisuals.Spacing.control) {
			Image(systemName: "globe")
				.font(.caption)
				.foregroundStyle(.secondary)
				.frame(width: 18)
				.accessibilityHidden(true)
			Text(region.displayName)
			Spacer(minLength: LauncherVisuals.Spacing.control)
			Text(durationText(controller.duration(for: region)))
				.font(.callout.monospacedDigit().weight(.semibold))
		}
		.padding(.vertical, LauncherVisuals.Spacing.control)
	}

	private func durationText(_ duration: TimeInterval) -> String {
		guard duration > 0 else {
			return Duration.seconds(0).formatted(
				.units(allowed: [.minutes], width: .abbreviated)
					.locale(locale)
			)
		}
		guard duration >= 60 else { return PlaytimeStrings.lessThanMinute }
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
