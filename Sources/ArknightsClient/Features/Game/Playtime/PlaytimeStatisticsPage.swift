// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct PlaytimeStatisticsPage: View {
	let controller: PlaytimeStatisticsController
	let accentColor: Color
	@State private var confirmsReset = false

	var body: some View {
		SettingsPage(
			title: L10n.string(PlaytimeStrings.title),
			subtitle: L10n.string(PlaytimeStrings.subtitle),
			accentColor: accentColor
		) {
			SettingsPanel(
				title: L10n.string(PlaytimeStrings.overview),
				systemImage: "clock"
			) {
				HStack(spacing: 0) {
					metric(
						L10n.string(PlaytimeStrings.total),
						duration: controller.totalDuration
					)
					metricDivider
					metric(
						L10n.string(PlaytimeStrings.sevenDays),
						duration: controller.duration(inLast: 7)
					)
					metricDivider
					metric(
						L10n.string(PlaytimeStrings.thirtyDays),
						duration: controller.duration(inLast: 30)
					)
				}
				SettingsHairline()
				latestSession
			}

			SettingsPanel(
				title: L10n.string(PlaytimeStrings.regions),
				systemImage: "globe"
			) {
				ForEach(Array(GameRegion.allCases.enumerated()), id: \.element.id) {
					index, region in
					if index > 0 { SettingsHairline() }
					HStack {
						Text(region.localizedDisplayName)
						Spacer()
						Text(durationText(controller.duration(for: region)))
							.font(.callout.monospacedDigit().weight(.semibold))
					}
				}
			}

			SettingsPanel(
				title: L10n.string(PlaytimeStrings.about),
				systemImage: "info.circle"
			) {
				explanation(
					title: L10n.string(PlaytimeStrings.measurement),
					detail: L10n.string(PlaytimeStrings.measurementDetail),
					systemImage: "clock.badge.checkmark"
				)
				SettingsHairline()
				explanation(
					title: L10n.string(PlaytimeStrings.privacy),
					detail: L10n.string(PlaytimeStrings.privacyDetail),
					systemImage: "lock"
				)
			}

			DangerZonePanel {
				SettingsActionRow(
					title: L10n.string(PlaytimeStrings.reset),
					detail: L10n.string(PlaytimeStrings.resetDetail)
				) {
					CapsuleActionButton(
						title: L10n.string(PlaytimeStrings.resetAction),
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
						L10n.string(PlaytimeStrings.resetConfirmation),
						isPresented: $confirmsReset,
						titleVisibility: .visible
					) {
						Button(
							L10n.string(PlaytimeStrings.resetConfirm),
							role: .destructive,
							action: controller.reset
						)
						Button(L10n.string(SettingsStrings.cancel), role: .cancel) {}
					} message: {
						Text(PlaytimeStrings.resetDetail)
					}
				}
			}
		}
	}

	private var locale: Locale {
		L10n.activeLocale ?? .autoupdatingCurrent
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
					title: L10n.string(PlaytimeStrings.latest),
					detail:
						"\(session.region.localizedDisplayName) · \(dateText(session.startedAt))"
				) {
					Text(durationText(session.duration))
						.font(.callout.monospacedDigit().weight(.semibold))
				}
			} else {
				SettingsActionRow(
					title: L10n.string(PlaytimeStrings.latest),
					detail: L10n.string(PlaytimeStrings.noSessions)
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
				.foregroundStyle(accentColor)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: 3) {
				Text(title)
				Text(detail)
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

	private func durationText(_ duration: TimeInterval) -> String {
		guard duration > 0 else {
			return Duration.seconds(0).formatted(
				.units(allowed: [.minutes], width: .abbreviated)
					.locale(locale)
			)
		}
		guard duration >= 60 else { return L10n.string(PlaytimeStrings.lessThanMinute) }
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
