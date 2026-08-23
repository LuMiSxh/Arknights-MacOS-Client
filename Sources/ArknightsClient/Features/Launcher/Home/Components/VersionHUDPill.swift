// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Expands the installed game version into an independent manual update check.
struct VersionHUDPill: View {
	@Bindable var model: LauncherViewModel
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isExpanded = false
	@State private var isHovering = false

	var body: some View {
		VStack(alignment: .leading, spacing: isExpanded ? 10 : 0) {
			Button(action: toggleExpansion) {
				HStack(spacing: 5) {
					Image(systemName: "number")
						.font(.system(size: 10, weight: .semibold))
						.foregroundStyle(model.accentColor)
					Text(model.versionText)
						.font(.system(size: 11, weight: .medium, design: .monospaced))
						.foregroundStyle(isHovering ? .primary : .secondary)
						.lineLimit(1)
						.truncationMode(.tail)
						.frame(
							maxWidth: isExpanded
								? .infinity
								: AppConstants.HUD.collapsedVersionTitleMaxWidth,
							alignment: .leading
						)
					Spacer(minLength: isExpanded ? 6 : 0)
					if isExpanded {
						Image(systemName: "chevron.down")
							.font(.caption.bold())
							.foregroundStyle(model.accentColor.opacity(isHovering ? 1 : 0.65))
							.accessibilityHidden(true)
					}
				}
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.onHover { isHovering = $0 }
			.help(
				L10n.string(
					isExpanded ? HomeStrings.versionHideDetails : HomeStrings.versionShowDetails
				)
			)

			if isExpanded {
				HStack(spacing: 10) {
					Label(updateStatus, systemImage: updateStatusIcon)
						.font(.caption)
						.foregroundStyle(
							model.isGameUpdateAvailable ? model.accentColor : .secondary
						)
						.lineLimit(1)
					Spacer()
					CapsuleActionButton(
						L10n.string(HomeStrings.versionCheckNow),
						systemImage: "arrow.clockwise",
						tone: .accent(model.accentColor), presentation: .hud,
						action: model.checkGameUpdates
					)
					.disabled(cannotCheck)
				}
				.transition(expandedContentTransition)
			}
		}
		.padding(.horizontal, isExpanded ? 14 : 12)
		.padding(.vertical, isExpanded ? 11 : 0)
		.frame(
			width: isExpanded ? AppConstants.HUD.expandedVersionWidth : nil,
			height: isExpanded
				? AppConstants.HUD.expandedVersionHeight
				: AppConstants.Music.collapsedPlayerHeight,
			alignment: isExpanded ? .topLeading : .center
		)
		.frame(
			maxWidth: isExpanded
				? AppConstants.HUD.expandedVersionWidth
				: AppConstants.HUD.collapsedVersionMaxWidth
		)
		.fixedSize(horizontal: !isExpanded, vertical: false)
		.clipped()
		.adaptiveGlassEffect(
			tint: model.hudTintColor,
			in: RoundedRectangle(cornerRadius: isExpanded ? 20 : 40)
		)
		.shadow(
			color: Color.black.opacity(isExpanded ? 0.35 : 0),
			radius: isExpanded ? 12 : 0,
			y: isExpanded ? 5 : 0
		)
		.accessibilityElement(children: .contain)
	}

	private var cannotCheck: Bool {
		model.phase == .checking || model.isDownloading || model.isGameActive
	}

	private var updateStatus: String {
		if model.phase == .checking { return L10n.string(HomeStrings.versionChecking) }
		if model.isGameUpdateAvailable,
			let latest = model.configuration?.gameLatestVersion
		{
			return L10n.string(HomeStrings.versionAvailable(latest))
		}
		return L10n.string(HomeStrings.versionUpToDate)
	}

	private var updateStatusIcon: String {
		if model.phase == .checking { return "arrow.trianglehead.2.clockwise" }
		return model.isGameUpdateAvailable ? "arrow.down.circle" : "checkmark.circle"
	}

	private var expandedContentTransition: AnyTransition {
		if reduceMotion { return .opacity }
		return .opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing))
	}

	private func toggleExpansion() {
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
