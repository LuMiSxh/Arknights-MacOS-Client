// SPDX-License-Identifier: MPL-2.0

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
						if installation.isDownloading {
							downloadProgressDetail
						} else {
							Text(detail)
								.font(.caption)
								.foregroundStyle(.secondary)
								.lineLimit(1)
						}
					}
					transferDetails
				}

				ProgressView(value: installation.progress?.fraction ?? 0)
					.progressViewStyle(.linear)
					.tint(accentColor)
					.animation(
						.linear(duration: 0.2), value: installation.progress?.fraction ?? 0)
			}
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(Text(statusTitle))
			.accessibilityValue(Text(accessibilityProgressValue))
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
					transferDetails
					statusAction
				}
			}
		}
	}

	@ViewBuilder
	private var statusAction: some View {
		if lifecycle.failure == nil,
			installation.isInstalled, let code = intelTranslation.supportCode
		{
			VStack(alignment: .leading, spacing: 4) {
				LauncherSupportCodeLabel(code: code, accentColor: accentColor)
				ViewThatFits(in: .horizontal) {
					HStack(spacing: 10) { intelTranslationActions(code: code) }
					VStack(alignment: .leading, spacing: 4) {
						intelTranslationActions(code: code)
					}
				}
				.font(.caption)
			}
		}
	}

	@ViewBuilder
	private func intelTranslationActions(code: SupportCode) -> some View {
		if intelTranslation.canInstallRosetta {
			AccentActionLink(
				title: intelTranslation.installationActionTitle,
				accentColor: accentColor,
				action: requestRosettaInstallation
			)
		} else if intelTranslation.canRetryAvailabilityCheck {
			AccentActionLink(
				title: L10n.string(HomeStrings.checkAgain),
				accentColor: accentColor,
				action: retryIntelTranslationCheck
			)
		}
		AccentLink(
			title: L10n.string(HomeStrings.openTroubleshooting),
			destination: code.troubleshootingURL,
			accentColor: accentColor
		)
	}

	private var statusTitle: String {
		if lifecycle.presentation.status == .pausing { return lifecycle.activityMessage }
		if installation.isDownloading, let progress = installation.progress {
			return L10n.string(HomeStrings.downloadPercentage(Int(progress.fraction * 100)))
		}
		if lifecycle.failure?.blocksGameLaunch == true {
			return L10n.string(HomeStrings.needsAttention)
		}
		if installation.isInstalled, let title = intelTranslation.statusTitle { return title }
		return lifecycle.activityMessage
	}

	private var statusDetail: String? {
		if installation.isDownloading, let progress = installation.progress {
			let downloaded = DownloadProgressFormatting.byteCount(progress.downloadedBytes)
			let total = DownloadProgressFormatting.byteCount(progress.totalBytes)
			return L10n.string(
				HomeStrings.downloadProgress(downloaded: downloaded, total: total)
			)
		}
		if lifecycle.failure?.blocksGameLaunch == true { return nil }
		if installation.isInstalled { return intelTranslation.statusDetail }
		return nil
	}

	private var accessibilityProgressValue: String {
		var values: [String] = []
		if let statusDetail { values.append(statusDetail) }
		if let progress = installation.progress {
			if let rate = progress.transferRateBytesPerSecond {
				values.append(
					L10n.string(
						HomeStrings.downloadSpeed(
							DownloadProgressFormatting.byteRate(rate)
						)
					)
				)
			} else if progress.isTransferStalled {
				values.append(L10n.string(HomeStrings.downloadWaiting))
			}
		}
		return values.joined(separator: ", ")
	}

	private var downloadProgressDetail: some View {
		Text(statusDetail ?? "")
			.font(.caption)
			.foregroundStyle(.secondary)
			.monospacedDigit()
			.frame(
				minWidth: AppConstants.HUD.downloadProgressDetailMinWidth,
				alignment: .leading
			)
			.fixedSize(horizontal: false, vertical: true)
			.layoutPriority(1)
			.accessibilityLabel(Text(statusDetail ?? ""))
	}

	@ViewBuilder
	private var transferDetails: some View {
		if installation.isDownloading, let progress = installation.progress {
			HStack(spacing: 7) {
				if let rate = progress.transferRateBytesPerSecond {
					Text(
						L10n.string(
							HomeStrings.downloadSpeed(
								DownloadProgressFormatting.byteRate(rate)
							)
						)
					)
					.monospacedDigit()
					.frame(
						minWidth: AppConstants.HUD.downloadSpeedDetailMinWidth,
						alignment: .leading
					)
				} else if progress.isTransferStalled {
					Text(L10n.string(HomeStrings.downloadWaiting))
						.frame(
							minWidth: AppConstants.HUD.downloadSpeedDetailMinWidth,
							alignment: .leading
						)
				}
			}
			.font(.caption)
			.foregroundStyle(.secondary)
			.lineLimit(1)
			.accessibilityElement(children: .combine)
		}
	}
}
