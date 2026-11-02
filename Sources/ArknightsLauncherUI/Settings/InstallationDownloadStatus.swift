// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

// Only this leaf reads the per-tick download progress, so the page body does not re-render on every update.
struct InstallationDownloadStatus: View {
	@Environment(\.launcherTheme) private var theme
	let installation: InstallationController

	var body: some View {
		let progress = installation.progress
		VStack(alignment: .trailing, spacing: 2) {
			Text(
				LauncherDownloadProgressPresentation.gameStatus(
					isDownloading: installation.isDownloading,
					progress: progress,
					isInstalled: installation.isInstalled,
					hasPartialDownload: installation.hasPartialDownload
				)
			)
			.foregroundStyle(installation.isDownloading ? theme.accentInk : theme.textSecondary)
			if installation.isDownloading,
				let transfer = LauncherDownloadProgressPresentation.transferDetail(
					for: progress,
					isPaused: false
				)
			{
				Text(transfer)
					.monospacedDigit()
					.frame(
						minWidth: AppConstants.HUD.downloadSpeedDetailMinWidth,
						alignment: .trailing
					)
					.font(.caption)
					.foregroundStyle(theme.textSecondary)
					.lineLimit(1)
			}
		}
		.accessibilityElement(children: .combine)
	}
}
