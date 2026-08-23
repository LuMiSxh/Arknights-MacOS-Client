// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

struct LauncherActivityStatusView: View {
	let lifecycle: LauncherLifecycleStore
	let installation: InstallationController
	let intelTranslation: IntelTranslationController
	let accentColor: Color
	let requestRosettaInstallation: () -> Void
	let retryIntelTranslationCheck: () -> Void

	@ViewBuilder
	var body: some View {
		if installation.isDownloading {
			VStack(alignment: .leading, spacing: 7) {
				HStack(alignment: .firstTextBaseline, spacing: 10) {
					Text(statusTitle)
						.font(.system(size: 14, weight: .semibold))
						.contentTransition(.numericText())
					if let detail = statusDetail {
						Text(detail)
							.font(.caption)
							.foregroundStyle(.secondary)
							.lineLimit(1)
					}
				}

				ProgressView(value: installation.progress?.fraction ?? 0)
					.progressViewStyle(.linear)
					.tint(accentColor)
					.animation(
						.linear(duration: 0.2), value: installation.progress?.fraction ?? 0)
			}
		} else {
			VStack(alignment: .leading, spacing: 2) {
				Text(statusTitle)
					.font(.system(size: 14, weight: .semibold))
					.contentTransition(.opacity)
				if let detail = statusDetail {
					Text(detail)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(1)
					statusAction(detail: detail)
				}
			}
		}
	}

	@ViewBuilder
	private func statusAction(detail: String) -> some View {
		if lifecycle.failureMessage != nil {
			AccentActionLink(
				title: L10n.string(HomeStrings.reportProblem),
				accentColor: accentColor
			) {
				NSWorkspace.shared.open(IssueReportURL.build(problem: detail))
			}
			.font(.caption)
		} else if installation.isInstalled && intelTranslation.canInstallRosetta {
			AccentActionLink(
				title: intelTranslation.installationActionTitle,
				accentColor: accentColor,
				action: requestRosettaInstallation
			)
			.font(.caption)
		} else if installation.isInstalled && intelTranslation.canRetryAvailabilityCheck {
			AccentActionLink(
				title: L10n.string(HomeStrings.checkAgain),
				accentColor: accentColor,
				action: retryIntelTranslationCheck
			)
			.font(.caption)
		}
	}

	private var statusTitle: String {
		if lifecycle.presentation.status == .pausing { return lifecycle.activityMessage }
		if installation.isDownloading, let progress = installation.progress {
			return L10n.string(HomeStrings.downloadPercentage(Int(progress.fraction * 100)))
		}
		if lifecycle.failureMessage != nil { return L10n.string(HomeStrings.needsAttention) }
		if installation.isInstalled, let title = intelTranslation.statusTitle { return title }
		return lifecycle.activityMessage
	}

	private var statusDetail: String? {
		if installation.isDownloading, let progress = installation.progress {
			let downloaded = ByteCountFormatter.string(
				fromByteCount: progress.downloadedBytes,
				countStyle: .file
			)
			let total = ByteCountFormatter.string(
				fromByteCount: progress.totalBytes,
				countStyle: .file
			)
			return L10n.string(
				HomeStrings.downloadProgress(downloaded: downloaded, total: total)
			)
		}
		if let failureMessage = lifecycle.failureMessage { return failureMessage }
		if installation.isInstalled { return intelTranslation.statusDetail }
		return nil
	}
}
