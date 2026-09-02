// SPDX-License-Identifier: MPL-2.0

import SwiftUI

extension InstallationSettingsPage {
	@ViewBuilder
	var transferDetails: some View {
		if installation.isDownloading, let progress = installation.progress {
			VStack(alignment: .trailing, spacing: 1) {
				if let rate = progress.transferRateBytesPerSecond {
					Text(
						L10n.string(
							SettingsStrings.downloadSpeed(
								DownloadProgressFormatting.byteRate(rate)
							)
						)
					)
					.monospacedDigit()
					.frame(
						minWidth: AppConstants.HUD.downloadSpeedDetailMinWidth,
						alignment: .trailing
					)
				} else if progress.isTransferStalled {
					Text(L10n.string(SettingsStrings.downloadWaiting))
						.frame(
							minWidth: AppConstants.HUD.downloadSpeedDetailMinWidth,
							alignment: .trailing
						)
				}
			}
			.font(.caption)
			.foregroundStyle(.secondary)
			.lineLimit(1)
		}
	}
}
