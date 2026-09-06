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
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isExpanded = false
	@State private var isHovering = false

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
			.adaptiveGlassEffect(
				tint: hudTintColor,
				in: RoundedRectangle(cornerRadius: isExpanded && canExpand ? 20 : 40)
			)
			.shadow(
				color: Color.black.opacity(isExpanded && canExpand ? 0.35 : 0),
				radius: isExpanded && canExpand ? 12 : 0,
				y: isExpanded && canExpand ? 5 : 0
			)
			.accessibilityElement(children: .contain)
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
			.buttonStyle(.plain)
			.keyboardFocusIndicator(in: RoundedRectangle(cornerRadius: 8))
			.onHover { isHovering = $0 }
			.accessibilityLabel(
				L10n.string(
					isExpanded ? HomeStrings.resetHideDetails : HomeStrings.resetShowDetails
				)
			)
			.accessibilityValue(Text(selectedCountdown))
			.help(
				L10n.string(
					isExpanded ? HomeStrings.resetHideDetails : HomeStrings.resetShowDetails
				)
			)
		} else {
			headerLabel
		}
	}

	private var headerLabel: some View {
		HStack(spacing: 5) {
			Image(systemName: "clock")
				.font(.caption.weight(.semibold))
				.foregroundStyle(accentColor)
				.accessibilityHidden(true)
			Text(selectedCountdown)
				.font(.caption.monospaced().weight(.medium))
				.foregroundStyle(isHovering ? .primary : .secondary)
				.lineLimit(2)
				.truncationMode(.tail)
				.fixedSize(horizontal: false, vertical: true)
				.frame(
					maxWidth: isExpanded && canExpand
						? nil
						: AppConstants.HUD.collapsedStatusTitleMaxWidth,
					alignment: .leading
				)
			Spacer(minLength: isExpanded && canExpand ? 6 : 0)
			if isExpanded && canExpand {
				Image(systemName: "chevron.down")
					.font(.caption.bold())
					.foregroundStyle(accentColor.opacity(isHovering ? 1 : 0.65))
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

	private var installedRegionRows: some View {
		VStack(alignment: .leading, spacing: 6) {
			ForEach(installation.installedRegions) { region in
				let countdown = ServerReset.countdownText(for: region)
				Button {
					selectRegion(region)
					withAnimation(reduceMotion ? nil : .snappy) {
						isExpanded = false
					}
				} label: {
					HStack(spacing: 8) {
						Text(region.localizedDisplayName)
							.font(.caption.weight(.semibold))
							.foregroundStyle(
								region == installation.region ? accentColor : .primary
							)
							.lineLimit(1)
						Text(countdown)
							.font(.caption.monospaced().weight(.medium))
							.foregroundStyle(.secondary)
							.lineLimit(1)
						if region == installation.region {
							Image(systemName: "checkmark")
								.font(.caption.bold())
								.foregroundStyle(accentColor)
								.accessibilityHidden(true)
						} else {
							Image(systemName: "chevron.right")
								.font(.caption.weight(.semibold))
								.foregroundStyle(.tertiary)
								.accessibilityHidden(true)
						}
					}
					.padding(.horizontal, 14)
					.padding(.vertical, 3)
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.keyboardFocusIndicator(in: RoundedRectangle(cornerRadius: 8))
				.disabled(!canSwitchRegion)
				.accessibilityElement(children: .combine)
				.accessibilityValue(Text(countdown))
				.accessibilityAddTraits(
					region == installation.region ? .isSelected : []
				)
				.accessibilityHint(Text(L10n.string(HomeStrings.switchRegionHelp)))
			}
		}
	}

	private var expandedContentTransition: AnyTransition {
		if reduceMotion { return .opacity }
		return .opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing))
	}

	private func toggleExpansion() {
		guard canExpand else { return }
		withAnimation(
			reduceMotion
				? nil
				: .snappy(
					duration: AppConstants.HUD.expansionDuration,
					extraBounce: 0.04
				)
		) {
			isExpanded.toggle()
		}
	}
}
