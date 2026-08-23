// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

struct LauncherActivityStatusView: View {
	let model: LauncherViewModel
	let accentColor: Color
	let requestRosettaInstallation: () -> Void
	let retryIntelTranslationCheck: () -> Void

	@ViewBuilder
	var body: some View {
		if model.isDownloading {
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

				ProgressView(value: model.progress?.fraction ?? 0)
					.progressViewStyle(.linear)
					.tint(accentColor)
					.animation(.linear(duration: 0.2), value: model.progress?.fraction ?? 0)
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
		if model.failureMessage != nil {
			AccentActionLink(
				title: L10n.string(HomeStrings.reportProblem),
				accentColor: accentColor
			) {
				NSWorkspace.shared.open(IssueReportURL.build(problem: detail))
			}
			.font(.caption)
		} else if model.isInstalled && model.canInstallRosetta {
			AccentActionLink(
				title: model.rosettaInstallationActionTitle,
				accentColor: accentColor,
				action: requestRosettaInstallation
			)
			.font(.caption)
		} else if model.isInstalled && model.canRetryIntelTranslationCheck {
			AccentActionLink(
				title: L10n.string(HomeStrings.checkAgain),
				accentColor: accentColor,
				action: retryIntelTranslationCheck
			)
			.font(.caption)
		}
	}

	private var statusTitle: String {
		if model.state.presentation.status == .pausing { return model.activityMessage }
		if model.isDownloading, let progress = model.progress {
			return L10n.string(HomeStrings.downloadPercentage(Int(progress.fraction * 100)))
		}
		if model.failureMessage != nil { return L10n.string(HomeStrings.needsAttention) }
		if model.isInstalled, let title = model.intelTranslationStatusTitle { return title }
		return model.activityMessage
	}

	private var statusDetail: String? {
		if model.isDownloading, let progress = model.progress {
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
		if let failureMessage = model.failureMessage { return failureMessage }
		if model.isInstalled { return model.intelTranslationStatusDetail }
		return nil
	}
}
