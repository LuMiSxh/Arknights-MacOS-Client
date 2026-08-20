// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Floating pill above the main control bar showing region and server reset countdown.
/// Renders nothing when neither has content, matching the single-region/no-extras default
/// the landing page starts from.
struct StatusHUDPill: View {
	var model: LauncherViewModel

	var body: some View {
		if hasContent {
			HStack(spacing: 6) {
				if let countdown = model.resetCountdownText {
					Image(systemName: "clock")
						.font(.system(size: 10, weight: .semibold))
						.foregroundStyle(model.accentColor)
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
			.adaptiveGlassEffect(tint: model.hudTintColor, in: Capsule())
		}
	}

	private var hasContent: Bool {
		model.resetCountdownText != nil
			|| model.installedRegions.count > 1
			|| model.region != .global
	}

	/// Stays invisible for the common single-region case; only becomes an interactive
	/// switcher once a second region is actually installed, so the landing page doesn't
	/// carry region chrome nobody can use yet.
	@ViewBuilder
	private var regionIndicator: some View {
		if model.installedRegions.count > 1 {
			Menu {
				ForEach(model.installedRegions) { region in
					Button {
						model.selectRegion(region)
					} label: {
						if region == model.region {
							Label(region.displayName, systemImage: "checkmark")
						} else {
							Text(region.displayName)
						}
					}
				}
			} label: {
				HStack(spacing: 3) {
					Text(model.region.displayName)
					Image(systemName: "chevron.up.chevron.down")
						.font(.system(size: 7, weight: .bold))
						.accessibilityHidden(true)
				}
				.font(.system(size: 10, weight: .semibold))
				.foregroundStyle(model.accentColor)
				.padding(.horizontal, 6)
				.padding(.vertical, 2)
				.background(model.accentColor.opacity(0.15), in: Capsule())
			}
			.menuStyle(.button)
			.buttonStyle(.plain)
			.disabled(!model.canSwitchRegion)
			.help("Switch between installed regions")
		} else if model.region != .global {
			Text(model.region.displayName)
				.font(.system(size: 10, weight: .semibold))
				.foregroundStyle(model.accentColor)
				.padding(.horizontal, 6)
				.padding(.vertical, 2)
				.background(model.accentColor.opacity(0.15), in: Capsule())
		}
	}
}
