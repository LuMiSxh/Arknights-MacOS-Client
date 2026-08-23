// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Floating pill above the main control bar showing region and server reset countdown.
/// Renders nothing when neither has content, matching the single-region/no-extras default
/// the landing page starts from.
struct StatusHUDPill: View {
	let settings: LauncherPreferencesController
	let installation: InstallationController
	let canSwitchRegion: Bool
	let accentColor: Color
	let hudTintColor: Color
	let selectRegion: (GameRegion) -> Void

	var body: some View {
		if hasContent {
			HStack(spacing: 6) {
				if let countdown = settings.resetCountdownText {
					Image(systemName: "clock")
						.font(.system(size: 10, weight: .semibold))
						.foregroundStyle(accentColor)
					Text(countdown)
						.font(.system(size: 11, weight: .medium, design: .monospaced))
						.foregroundStyle(.secondary)
						.lineLimit(1)
						.truncationMode(.tail)
						.frame(
							maxWidth: AppConstants.HUD.collapsedStatusTitleMaxWidth
						)
				}
				regionIndicator
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 7)
			.frame(maxWidth: AppConstants.HUD.collapsedStatusMaxWidth)
			.fixedSize(horizontal: true, vertical: false)
			.adaptiveGlassEffect(tint: hudTintColor, in: Capsule())
		}
	}

	private var hasContent: Bool {
		settings.resetCountdownText != nil
			|| installation.installedRegions.count > 1
			|| installation.region != .global
	}

	/// Stays invisible for the common single-region case; only becomes an interactive
	/// switcher once a second region is actually installed, so the landing page doesn't
	/// carry region chrome nobody can use yet.
	@ViewBuilder
	private var regionIndicator: some View {
		if installation.installedRegions.count > 1 {
			Menu {
				ForEach(installation.installedRegions) { region in
					Button {
						selectRegion(region)
					} label: {
						if region == installation.region {
							Label(region.localizedDisplayName, systemImage: "checkmark")
						} else {
							Text(region.localizedDisplayName)
						}
					}
				}
			} label: {
				HUDMenuLabel(
					title: installation.region.localizedDisplayName,
					accentColor: accentColor,
					showsMenuIndicator: true
				)
			}
			.menuStyle(.button)
			.buttonStyle(.plain)
			.disabled(!canSwitchRegion)
			.help(L10n.string(HomeStrings.switchRegionHelp))
		} else if installation.region != .global {
			HUDMenuLabel(
				title: installation.region.localizedDisplayName,
				accentColor: accentColor
			)
		}
	}
}
