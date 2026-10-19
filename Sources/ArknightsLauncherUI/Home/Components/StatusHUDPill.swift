// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

struct StatusHUDPill: View {
	package let settings: LauncherPreferencesController
	package let installation: InstallationController
	let canSwitchRegion: Bool
	package let accentColor: Color
	let hudTintColor: Color
	package let selectRegion: (GameRegion) -> Void
	@Binding var isExpanded: Bool
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		if settings.showsServerResetCountdown {
			// Countdowns show whole minutes, so redrawing on minute boundaries keeps them exact.
			TimelineView(.everyMinute) { context in
				pill(now: context.date)
			}
		}
	}

	private func pill(now: Date) -> some View {
		let expanded = isExpanded && canExpand
		return ExpandableHUDPill(
			systemImage: "clock",
			toggleNoun: "reset details",
			accessibilityValue: countdown(for: installation.region, now: now),
			accentColor: accentColor,
			hudTintColor: hudTintColor,
			canExpand: canExpand,
			sizing: HUDPillSizing(
				collapsedHeight: AppConstants.Music.collapsedPlayerHeight,
				collapsedMaxWidth: AppConstants.HUD.collapsedStatusMaxWidth,
				expandedMinWidth: AppConstants.HUD.expandedStatusMinWidth,
				expandedMaxWidth: AppConstants.HUD.expandedStatusWidth,
				fixesWidthWhenExpanded: true
			),
			isExpanded: $isExpanded
		) {
			Text(countdown(for: installation.region, now: now))
				.font(.caption.monospaced().weight(.medium))
				.foregroundStyle(.secondary)
				.lineLimit(2)
				.truncationMode(.tail)
				.fixedSize(horizontal: false, vertical: true)
				.frame(
					maxWidth: expanded ? nil : AppConstants.HUD.collapsedStatusTitleMaxWidth,
					alignment: .leading
				)
		} detail: {
			installedRegionRows(now: now)
		}
	}

	private var canExpand: Bool {
		installation.installedRegions.count > 1
	}

	private func countdown(for region: GameRegion, now: Date) -> String {
		ServerReset.countdownText(for: region, now: now)
	}

	private func installedRegionRows(now: Date) -> some View {
		VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.compact) {
			ForEach(installation.installedRegions) { region in
				let countdown = countdown(for: region, now: now)
				Button {
					selectRegion(region)
					withAnimation(HUDPillMotion.expansionAnimation(reduceMotion: reduceMotion)) {
						isExpanded = false
					}
				} label: {
					regionRowLabel(region: region, countdown: countdown)
				}
				.buttonStyle(ActionPressStyle())
				.keyboardFocusIndicator(
					in: RoundedRectangle(cornerRadius: LauncherVisuals.Radius.row)
				)
				.disabled(!canSwitchRegion)
				.accessibilityElement(children: .ignore)
				.accessibilityLabel(Text(region.displayName))
				.accessibilityValue(Text(countdown))
				.accessibilityAddTraits(
					region == installation.region ? .isSelected : []
				)
				.accessibilityHint(Text("Switch between installed regions"))
			}
		}
		.padding(.horizontal, LauncherVisuals.Spacing.control)
		.padding(.vertical, LauncherVisuals.Spacing.control)
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private func regionRowLabel(region: GameRegion, countdown: String) -> some View {
		HStack(spacing: LauncherVisuals.Spacing.control) {
			VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.compact) {
				Text(region.displayName)
					.font(.caption.weight(.semibold))
					.adaptiveControlForeground(
						.primary,
						disabledTint: LauncherVisuals.disabled
					)
					.fixedSize(horizontal: false, vertical: true)
				Text(countdown)
					.font(.caption.monospacedDigit().weight(.medium))
					.adaptiveControlForeground(
						.secondary,
						disabledTint: LauncherVisuals.disabled
					)
					.fixedSize(horizontal: false, vertical: true)
			}
			.frame(maxWidth: .infinity, alignment: .leading)

			Image(systemName: "checkmark")
				.font(.caption.bold())
				.adaptiveControlForeground(
					accentColor,
					disabledTint: LauncherVisuals.disabled
				)
				.opacity(region == installation.region ? 1 : 0)
				.frame(width: 16, alignment: .center)
				.accessibilityHidden(true)
		}
		.padding(.horizontal, LauncherVisuals.Spacing.control)
		.padding(.vertical, LauncherVisuals.Spacing.tight)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			rowFill(for: region), in: RoundedRectangle(cornerRadius: LauncherVisuals.Radius.row)
		)
		.contentShape(RoundedRectangle(cornerRadius: LauncherVisuals.Radius.row))
	}

	private func rowFill(for region: GameRegion) -> Color {
		guard region == installation.region else { return .clear }
		let opacity = canSwitchRegion ? 1 : 0.45
		return LauncherVisuals.selectedNavigationFill(for: accentColor).opacity(opacity)
	}
}
