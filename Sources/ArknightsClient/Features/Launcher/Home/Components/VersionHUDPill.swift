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
	@Binding var isExpanded: Bool
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		VStack(alignment: .leading, spacing: isExpanded ? 10 : 0) {
			Button(action: toggleExpansion) {
				HStack(spacing: 5) {
					Image(systemName: "number")
						.font(.caption.weight(.semibold))
						.adaptiveControlForeground(accentColor)
						.accessibilityHidden(true)
					Text(versionText)
						.font(.caption.monospaced().weight(.medium))
						.foregroundStyle(.secondary)
						.lineLimit(1)
						.truncationMode(.tail)
						.frame(
							maxWidth: isExpanded
								? .infinity
								: AppConstants.HUD.collapsedVersionTitleMaxWidth,
							alignment: .leading
						)
					Spacer(minLength: 6)
					Image(systemName: disclosureImage)
						.font(.caption.bold())
						.adaptiveControlForeground(accentColor)
						.contentTransition(
							HUDPillMotion.chevronTransition(reduceMotion: reduceMotion)
						)
						.accessibilityHidden(true)
				}
				.padding(.horizontal, isExpanded ? 14 : 12)
				.frame(minHeight: isExpanded ? nil : AppConstants.Music.collapsedPlayerHeight)
				.contentShape(Rectangle())
			}
			.buttonStyle(ActionPressStyle())
			.keyboardFocusIndicator(in: Capsule())
			.accessibilityLabel(

				isExpanded ? HomeStrings.versionHideDetails : HomeStrings.versionShowDetails

			)
			.accessibilityValue(Text(versionText))
			.help(

				isExpanded ? HomeStrings.versionHideDetails : HomeStrings.versionShowDetails

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
						title: HomeStrings.versionCheckNow,
						systemImage: "arrow.clockwise",
						tone: .accent(accentColor), presentation: .hud,
						action: checkGameUpdates
					)
					.disabled(cannotCheck)
				}
				.padding(.horizontal, 14)
				.transition(expandedContentTransition)
			}
		}
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
		.hudPillSurface(
			isExpanded: isExpanded,
			tint: hudTintColor,
			progressTint: accentColor
		)
		.shadow(
			color: Color.black.opacity(isExpanded ? 0.35 : 0),
			radius: isExpanded ? 12 : 0,
			y: isExpanded ? 5 : 0
		)
		.accessibilityElement(children: .contain)
		.onExitCommand(perform: collapseExpansion)
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
		if lifecycle.refresh.isChecking { return HomeStrings.versionChecking }
		if installation.isGameUpdateAvailable,
			let latest = installation.configuration?.gameLatestVersion
		{
			return HomeStrings.versionAvailable(latest)
		}
		return HomeStrings.versionUpToDate
	}

	private var updateStatusIcon: String {
		if lifecycle.refresh.isChecking { return "arrow.trianglehead.2.clockwise" }
		return installation.isGameUpdateAvailable ? "arrow.down.circle" : "checkmark.circle"
	}

	private var disclosureImage: String {
		isExpanded ? "chevron.up" : "chevron.down"
	}

	private var expandedContentTransition: AnyTransition {
		HUDPillMotion.expandedContentTransition(reduceMotion: reduceMotion)
	}

	private func toggleExpansion() {
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
