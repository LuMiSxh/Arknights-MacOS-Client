// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Expands the installed game version into an independent manual update check.
struct VersionHUDPill: View {
	let lifecycle: LauncherLifecycleStore
	let installation: InstallationController
	let gameSession: GameSessionController
	let accentColor: Color
	let hudTintColor: Color
	let checkGameUpdates: () -> Void
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isExpanded = false
	@State private var isHovering = false

	var body: some View {
		VStack(alignment: .leading, spacing: isExpanded ? 10 : 0) {
			Button(action: toggleExpansion) {
				HStack(spacing: 5) {
					Image(systemName: "number")
						.font(.system(size: 10, weight: .semibold))
						.foregroundStyle(accentColor)
						.accessibilityHidden(true)
					Text(versionText)
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
							.foregroundStyle(accentColor.opacity(isHovering ? 1 : 0.65))
							.accessibilityHidden(true)
					}
				}
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.keyboardFocusIndicator(
				in: RoundedRectangle(cornerRadius: 8)
			)
			.onHover { isHovering = $0 }
			.accessibilityLabel(
				L10n.string(
					isExpanded ? HomeStrings.versionHideDetails : HomeStrings.versionShowDetails
				)
			)
			.accessibilityValue(Text(versionText))
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
							installation.isGameUpdateAvailable ? accentColor : .secondary
						)
						.fixedSize(horizontal: false, vertical: true)
					Spacer()
					CapsuleActionButton(
						title: L10n.string(HomeStrings.versionCheckNow),
						systemImage: "arrow.clockwise",
						tone: .accent(accentColor), presentation: .hud,
						action: checkGameUpdates
					)
					.disabled(cannotCheck)
				}
				.transition(expandedContentTransition)
			}
		}
		.padding(.horizontal, isExpanded ? 14 : 12)
		.padding(.vertical, isExpanded ? 11 : 0)
		.frame(width: isExpanded ? AppConstants.HUD.expandedVersionWidth : nil)
		.frame(
			minHeight: isExpanded
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
		.adaptiveGlassEffect(
			tint: hudTintColor,
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
		!lifecycle.canBeginExclusiveActivity
			|| lifecycle.refresh.isChecking
			|| installation.isDownloading
			|| gameSession.isGameActive
	}

	private var versionText: String {
		installation.installedVersion ?? installation.configuration?.gameLatestVersion ?? "—"
	}

	private var updateStatus: String {
		if lifecycle.refresh.isChecking { return L10n.string(HomeStrings.versionChecking) }
		if installation.isGameUpdateAvailable,
			let latest = installation.configuration?.gameLatestVersion
		{
			return L10n.string(HomeStrings.versionAvailable(latest))
		}
		return L10n.string(HomeStrings.versionUpToDate)
	}

	private var updateStatusIcon: String {
		if lifecycle.refresh.isChecking { return "arrow.trianglehead.2.clockwise" }
		return installation.isGameUpdateAvailable ? "arrow.down.circle" : "checkmark.circle"
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
