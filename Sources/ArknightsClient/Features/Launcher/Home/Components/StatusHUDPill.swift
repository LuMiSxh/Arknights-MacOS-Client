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
		if hasContent {
			VStack(alignment: .leading, spacing: isExpanded && canExpand ? 10 : 0) {
				header
				if isExpanded && canExpand {
					installedRegionRows
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
	}

	private var hasContent: Bool {
		settings.resetCountdownText != nil
	}

	private var canExpand: Bool {
		installation.installedRegions.count > 1
	}

	@ViewBuilder
	private var header: some View {
		if canExpand {
			Button(action: toggleExpansion) {
				headerLabel
			}
			.buttonStyle(ActionPressStyle())
			.keyboardFocusIndicator(in: Capsule())
			.accessibilityLabel(

				isExpanded ? HomeStrings.resetHideDetails : HomeStrings.resetShowDetails

			)
			.accessibilityValue(Text(selectedCountdown))
			.help(

				isExpanded ? HomeStrings.resetHideDetails : HomeStrings.resetShowDetails

			)
		} else {
			headerLabel
		}
	}

	private var headerLabel: some View {
		HStack(spacing: 5) {
			Image(systemName: "clock")
				.font(.caption.weight(.semibold))
				.adaptiveControlForeground(accentColor)
				.accessibilityHidden(true)
			Text(selectedCountdown)
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

	private var selectedCountdown: String {
		settings.resetCountdownText ?? ""
	}

	private var disclosureImage: String {
		isExpanded ? "chevron.up" : "chevron.down"
	}

	private var installedRegionRows: some View {
		VStack(alignment: .leading, spacing: 6) {
			ForEach(installation.installedRegions) { region in
				let countdown = ServerReset.countdownText(for: region)
				Button {
					selectRegion(region)
					withAnimation(HUDPillMotion.expansionAnimation(reduceMotion: reduceMotion)) {
						isExpanded = false
					}
				} label: {
					HStack(spacing: 8) {
						Text(region.displayName)
							.font(.caption.weight(.semibold))
							.adaptiveControlForeground(
								region == installation.region ? accentColor : .primary,
								disabledTint: LauncherVisuals.disabled
							)
							.lineLimit(1)
						Text(countdown)
							.font(.caption.monospaced().weight(.medium))
							.adaptiveControlForeground(
								.secondary,
								disabledTint: LauncherVisuals.disabled
							)
							.lineLimit(1)
						if region == installation.region {
							Image(systemName: "checkmark")
								.font(.caption.bold())
								.adaptiveControlForeground(
									accentColor,
									disabledTint: LauncherVisuals.disabled
								)
								.accessibilityHidden(true)
						} else {
							Image(systemName: "chevron.right")
								.font(.caption.weight(.semibold))
								.adaptiveControlForeground(
									LauncherVisuals.controlTint.opacity(0.68),
									disabledTint: LauncherVisuals.disabled
								)
								.accessibilityHidden(true)
						}
					}
					.padding(.horizontal, 14)
					.padding(.vertical, 3)
					.adaptiveControlSurface(
						tint: LauncherVisuals.controlTint,
						isDisabled: !canSwitchRegion,
						in: RoundedRectangle(cornerRadius: LauncherVisuals.Radius.control)
					)
					.contentShape(RoundedRectangle(cornerRadius: LauncherVisuals.Radius.control))
				}
				.buttonStyle(ActionPressStyle())
				.keyboardFocusIndicator(
					in: RoundedRectangle(cornerRadius: LauncherVisuals.Radius.control)
				)
				.disabled(!canSwitchRegion)
				.accessibilityElement(children: .combine)
				.accessibilityValue(Text(countdown))
				.accessibilityAddTraits(
					region == installation.region ? .isSelected : []
				)
				.accessibilityHint(Text(HomeStrings.switchRegionHelp))
			}
		}
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
