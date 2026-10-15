// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

extension InstallationSettingsPage {
	@ViewBuilder
	var transferDetails: some View {
		if installation.isDownloading, let progress = installation.progress {
			VStack(alignment: .trailing, spacing: 1) {
				if let rate = progress.transferRateBytesPerSecond {
					Text(

						DownloadProgressFormatting.byteRate(rate)

					)
					.monospacedDigit()
					.frame(
						minWidth: AppConstants.HUD.downloadSpeedDetailMinWidth,
						alignment: .trailing
					)
				} else if progress.isTransferStalled {
					Text("Waiting for network…")
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
