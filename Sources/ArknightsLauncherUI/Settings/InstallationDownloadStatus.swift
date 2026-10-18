// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

// Only this leaf reads the per-tick download progress, so the page body does not re-render on every update.
struct InstallationDownloadStatus: View {
	let installation: InstallationController
	let accentColor: Color

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
			.foregroundStyle(installation.isDownloading ? accentColor : .secondary)
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
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
		}
		.accessibilityElement(children: .combine)
	}
}
