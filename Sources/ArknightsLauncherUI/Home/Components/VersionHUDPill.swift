// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

struct VersionHUDPill: View {
	let lifecycle: LauncherLifecycleStore
	let installation: InstallationController
	let gameSession: GameSessionController
	let checkGameUpdates: () -> Void
	@Binding var isExpanded: Bool
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		ExpandableHUDPill(
			systemImage: "number",
			toggleNoun: "version details",
			accessibilityValue: versionText,
			sizing: HUDPillSizing(
				collapsedHeight: AppConstants.Music.collapsedPlayerHeight,
				collapsedMaxWidth: AppConstants.HUD.collapsedVersionMaxWidth,
				expandedWidth: AppConstants.HUD.expandedVersionWidth,
				expandedMaxWidth: AppConstants.HUD.expandedVersionWidth,
				expandedMinHeight: AppConstants.HUD.expandedVersionHeight
			),
			isExpanded: $isExpanded
		) {
			Text(versionText)
				.font(.caption.monospacedDigit().weight(.medium))
				.foregroundStyle(theme.textSecondary)
				.lineLimit(1)
				.truncationMode(.tail)
				.frame(
					maxWidth: isExpanded
						? .infinity
						: AppConstants.HUD.collapsedVersionTitleMaxWidth,
					alignment: .leading
				)
		} detail: {
			HStack(spacing: 12) {
				Label(updateStatus, systemImage: updateStatusIcon)
					.font(.caption)
					.foregroundStyle(
						installation.isGameUpdateAvailable ? theme.accentInk : theme.textSecondary
					)
					.fixedSize(horizontal: false, vertical: true)
				Spacer()
				CapsuleActionButton(
					title: "Check Now",
					systemImage: "arrow.clockwise",
					tone: .accent, presentation: .hud,
					action: checkGameUpdates
				)
				.disabled(cannotCheck)
			}
			.padding(.horizontal, 16)
		}
	}

	private var cannotCheck: Bool {
		!lifecycle.canBeginExclusiveActivity
			|| lifecycle.state.refresh.isChecking
			|| installation.isDownloading
			|| gameSession.isGameActive
	}

	private var versionText: String {
		installation.installedVersion ?? installation.configuration?.gameLatestVersion ?? "—"
	}

	private var updateStatus: String {
		if lifecycle.state.refresh.isChecking { return "Checking…" }
		if installation.isGameUpdateAvailable,
			let latest = installation.configuration?.gameLatestVersion
		{
			return "\(latest) available"
		}
		return "Up to date"
	}

	private var updateStatusIcon: String {
		if lifecycle.state.refresh.isChecking { return "arrow.trianglehead.2.clockwise" }
		return installation.isGameUpdateAvailable ? "arrow.down.circle" : "checkmark.circle"
	}
}
