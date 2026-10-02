// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Floating pill above the main control bar showing the active client's server reset countdown.
/// Expands to show reset information for every installed client when region switching is useful.
struct StatusHUDPill: View {
	let settings: LauncherPreferencesController
	let installation: InstallationController
	let canSwitchRegion: Bool
	let accentColor: Color
	let hudTintColor: Color
	let selectRegion: (GameRegion) -> Void
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
		VStack(alignment: .leading, spacing: isExpanded && canExpand ? 10 : 0) {
			header(now: now)
			if isExpanded && canExpand {
				installedRegionRows(now: now)
					.transition(expandedContentTransition)
			}
		}
		.padding(.vertical, isExpanded && canExpand ? 11 : 0)
		.frame(
			minHeight: isExpanded && canExpand
				? nil
				: AppConstants.Music.collapsedPlayerHeight,
			alignment: isExpanded && canExpand ? .topLeading : .center
		)
		.frame(
			minWidth: isExpanded && canExpand
				? AppConstants.HUD.expandedStatusMinWidth
				: nil,
			maxWidth: isExpanded && canExpand
				? AppConstants.HUD.expandedStatusWidth
				: AppConstants.HUD.collapsedStatusMaxWidth
		)
		.fixedSize(horizontal: true, vertical: false)
		.hudPillSurface(
			isExpanded: isExpanded && canExpand,
			tint: hudTintColor,
			progressTint: accentColor
		)
		.shadow(
			color: Color.black.opacity(isExpanded && canExpand ? 0.35 : 0),
			radius: isExpanded && canExpand ? 12 : 0,
			y: isExpanded && canExpand ? 5 : 0
		)
		.accessibilityElement(children: .contain)
		.onExitCommand(perform: collapseExpansion)
	}

	private var canExpand: Bool {
		installation.installedRegions.count > 1
	}

	@ViewBuilder
	private func header(now: Date) -> some View {
		if canExpand {
			Button(action: toggleExpansion) {
				headerLabel(now: now)
			}
			.buttonStyle(ActionPressStyle())
			.keyboardFocusIndicator(in: Capsule())
			.accessibilityLabel(

				isExpanded ? HomeStrings.resetHideDetails : HomeStrings.resetShowDetails

			)
			.accessibilityValue(Text(countdown(for: installation.region, now: now)))
			.help(

				isExpanded ? HomeStrings.resetHideDetails : HomeStrings.resetShowDetails

			)
		} else {
			headerLabel(now: now)
		}
	}

	private func headerLabel(now: Date) -> some View {
		HStack(spacing: 5) {
			Image(systemName: "clock")
				.font(.caption.weight(.semibold))
				.adaptiveControlForeground(accentColor)
				.accessibilityHidden(true)
			Text(countdown(for: installation.region, now: now))
				.font(.caption.monospaced().weight(.medium))
				.foregroundStyle(.secondary)
				.lineLimit(2)
				.truncationMode(.tail)
				.fixedSize(horizontal: false, vertical: true)
				.frame(
					maxWidth: isExpanded && canExpand
						? nil
						: AppConstants.HUD.collapsedStatusTitleMaxWidth,
					alignment: .leading
				)
			Spacer(minLength: canExpand ? 6 : 0)
			if canExpand {
				Image(systemName: disclosureImage)
					.font(.caption.bold())
					.adaptiveControlForeground(accentColor)
					.contentTransition(HUDPillMotion.chevronTransition(reduceMotion: reduceMotion))
					.accessibilityHidden(true)
			}
		}
		.padding(.horizontal, isExpanded && canExpand ? 14 : 12)
		.frame(minHeight: isExpanded && canExpand ? nil : AppConstants.Music.collapsedPlayerHeight)
		.contentShape(Rectangle())
	}

	private func countdown(for region: GameRegion, now: Date) -> String {
		ServerReset.countdownText(for: region, now: now)
	}

	private var disclosureImage: String {
		isExpanded ? "chevron.up" : "chevron.down"
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
				.accessibilityHint(Text(HomeStrings.switchRegionHelp))
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

	private var expandedContentTransition: AnyTransition {
		HUDPillMotion.expandedContentTransition(reduceMotion: reduceMotion)
	}

	private func toggleExpansion() {
		guard canExpand else { return }
		withAnimation(HUDPillMotion.expansionAnimation(reduceMotion: reduceMotion)) {
			isExpanded.toggle()
		}
	}

	private func collapseExpansion() {
		guard isExpanded else { return }
		withAnimation(HUDPillMotion.expansionAnimation(reduceMotion: reduceMotion)) {
			isExpanded = false
		}
	}
}
