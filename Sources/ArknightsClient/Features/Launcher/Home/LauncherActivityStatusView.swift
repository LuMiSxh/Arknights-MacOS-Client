// SPDX-License-Identifier: MPL-2.0

import SwiftUI

enum LauncherDownloadProgressPresentation {
	static func percentage(for progress: DownloadProgress?) -> Int? {
		guard let progress, progress.totalBytes > 0 else { return nil }
		return Int(progress.fraction * 100)
	}

	static func title(for progress: DownloadProgress?, isPaused: Bool) -> String? {
		guard let percentage = percentage(for: progress) else { return nil }
		return isPaused
			? HomeStrings.pausedDownloadPercentage(percentage)
			: HomeStrings.downloadPercentage(percentage)
	}

	static func fraction(
		for progress: DownloadProgress?,
		isActive: Bool,
		isPaused: Bool
	) -> Double? {
		guard isActive || isPaused, let progress, progress.totalBytes > 0 else { return nil }
		return progress.fraction
	}

	static func outlineFraction(
		for progress: DownloadProgress?,
		status: LauncherStatus,
		hasPartialDownload: Bool,
		hasFailure: Bool
	) -> Double? {
		guard !hasFailure else { return nil }

		switch status {
		case .preparingInstallation, .verifyingInstallation:
			return 1
		case .downloading, .pausing:
			return knownFraction(for: progress)
		case .paused:
			return hasPartialDownload ? knownFraction(for: progress) : nil
		default:
			return nil
		}
	}

	static func showsActiveProgressEffect(
		for progress: DownloadProgress?,
		status: LauncherStatus,
		hasFailure: Bool
	) -> Bool {
		guard !hasFailure else { return false }
		if status == .preparingInstallation || status == .verifyingInstallation {
			return true
		}
		guard status == .downloading,
			let progress,
			!progress.isTransferStalled
		else { return false }

		return progress.fraction > 0 && progress.fraction < 1
	}

	private static func knownFraction(for progress: DownloadProgress?) -> Double? {
		guard let progress, progress.totalBytes > 0 else { return nil }
		return progress.fraction
	}

	static func transferDetail(
		for progress: DownloadProgress?,
		isPaused: Bool
	) -> String? {
		guard !isPaused, let progress else { return nil }
		if let rate = progress.transferRateBytesPerSecond {
			return HomeStrings.downloadSpeed(DownloadProgressFormatting.byteRate(rate))
		}
		if progress.isTransferStalled { return HomeStrings.downloadWaiting }
		return nil
	}

	static func accessibilityValue(
		for progress: DownloadProgress?,
		detail: String?,
		isPaused: Bool
	) -> String {
		var values: [String] = []
		if let detail { values.append(detail) }
		if let transferDetail = transferDetail(for: progress, isPaused: isPaused) {
			values.append(transferDetail)
		}
		return values.joined(separator: ", ")
	}
}

struct LauncherActivityStatusView: View {
	let lifecycle: LauncherLifecycleStore
	let installation: InstallationController
	let intelTranslation: IntelTranslationController
	let accentColor: Color
	let requestRosettaInstallation: () -> Void
	let retryIntelTranslationCheck: () -> Void
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var completionFeedback: InstallationCompletionFeedback?

	var body: some View {
		Group {
			if let completionFeedback, showsCompletionFeedback {
				HStack(spacing: 6) {
					LauncherCompletionFeedbackView(feedbackID: completionFeedback.id)
					Text(HomeStrings.installationComplete)
				}
				.font(.system(size: 14, weight: .semibold))
				.accessibilityElement(children: .combine)
				.accessibilityLabel(Text(HomeStrings.installationComplete))
			} else if showsDownloadSnapshot {
				VStack(alignment: .leading, spacing: 4) {
					ViewThatFits(in: .horizontal) {
						HStack(alignment: .firstTextBaseline, spacing: 10) {
							percentageLabel
							downloadProgressDetail
							transferDetails
						}
						VStack(alignment: .leading, spacing: 3) {
							percentageLabel
							HStack(alignment: .firstTextBaseline, spacing: 8) {
								downloadProgressDetail
								transferDetails
							}
						}
					}
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
		.onAppear(perform: consumeCompletionFeedback)
		.onChange(of: installation.completionFeedback?.id) { _, _ in
			consumeCompletionFeedback()
		}
		.onChange(of: lifecycle.failure?.id) { _, failureID in
			if failureID != nil { completionFeedback = nil }
		}
		.onChange(of: lifecycle.activity) { _, activity in
			if activity != .idle { completionFeedback = nil }
		}
		.onChange(of: installation.region) { _, region in
			if completionFeedback?.region != region { completionFeedback = nil }
		}
		.task(id: completionFeedback?.id) {
			guard let displayedFeedback = completionFeedback else { return }
			if reduceMotion {
				completionFeedback = nil
				return
			}
			do {
				try await Task.sleep(for: LauncherVisuals.Motion.completionFeedback)
			} catch {
				return
			}
			guard !Task.isCancelled,
				completionFeedback == displayedFeedback,
				displayedFeedback.region == installation.region,
				lifecycle.activity == .idle,
				lifecycle.failure == nil
			else {
				completionFeedback = nil
				return
			}
			completionFeedback = nil
			consumeCompletionFeedback()
		}
	}

	private var showsCompletionFeedback: Bool {
		LauncherCompletionFeedbackPresentation.isVisible(
			completionFeedback,
			currentRegion: installation.region,
			activity: lifecycle.activity,
			hasFailure: lifecycle.failure != nil
		)
	}

	private func consumeCompletionFeedback() {
		guard completionFeedback == nil else { return }
		completionFeedback = installation.consumeCompletionFeedback(for: installation.region)
	}

	@ViewBuilder
	private var statusAction: some View {
		if lifecycle.failure == nil,
			installation.isInstalled, let code = intelTranslation.supportCode
		{
			VStack(alignment: .leading, spacing: 4) {
				LauncherSupportCodeLabel(code: code)
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
				title: HomeStrings.checkAgain,
				accentColor: accentColor,
				action: retryIntelTranslationCheck
			)
		}
		AccentLink(
			title: HomeStrings.openTroubleshooting,
			destination: code.troubleshootingURL,
			accentColor: accentColor
		)
	}

	private var statusTitle: String {
		if lifecycle.presentation.status == .pausing { return lifecycle.activityMessage }
		if showsDownloadSnapshot,
			let title = LauncherDownloadProgressPresentation.title(
				for: installation.progress,
				isPaused: isPausedDownload
			)
		{
			return title
		}
		if lifecycle.failure?.blocksGameLaunch == true {
			return HomeStrings.needsAttention
		}
		if installation.isInstalled, let title = intelTranslation.statusTitle { return title }
		return lifecycle.activityMessage
	}

	private var statusDetail: String? {
		if showsDownloadSnapshot, let progress = installation.progress,
			progress.totalBytes > 0
		{
			let downloaded = DownloadProgressFormatting.byteCount(progress.downloadedBytes)
			let total = DownloadProgressFormatting.byteCount(progress.totalBytes)
			return
				HomeStrings.downloadProgress(downloaded: downloaded, total: total)

		}
		if lifecycle.failure?.blocksGameLaunch == true { return nil }
		if installation.isInstalled { return intelTranslation.statusDetail }
		return nil
	}

	private var accessibilityProgressValue: String {
		LauncherDownloadProgressPresentation.accessibilityValue(
			for: installation.progress,
			detail: statusDetail,
			isPaused: isPausedDownload
		)
	}

	private var isPausedDownload: Bool {
		lifecycle.presentation.status == .paused
			&& installation.hasPartialDownload
			&& lifecycle.failure == nil
	}

	private var showsDownloadSnapshot: Bool {
		guard lifecycle.failure == nil else { return false }
		return lifecycle.presentation.status == .downloading
			|| (isPausedDownload
				&& LauncherDownloadProgressPresentation.fraction(
					for: installation.progress,
					isActive: false,
					isPaused: true
				) != nil)
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

	private var percentageLabel: some View {
		Text(statusTitle)
			.font(.system(size: 16, weight: .semibold))
			.contentTransition(reduceMotion ? .identity : .numericText())
			.animation(
				reduceMotion ? nil : .easeInOut(duration: 0.16),
				value: statusTitle
			)
			.fixedSize(horizontal: true, vertical: false)
	}

	@ViewBuilder
	private var transferDetails: some View {
		if showsDownloadSnapshot,
			let transferDetail = LauncherDownloadProgressPresentation.transferDetail(
				for: installation.progress,
				isPaused: isPausedDownload
			)
		{
			Text(transferDetail)
				.monospacedDigit()
				.frame(
					minWidth: AppConstants.HUD.downloadSpeedDetailMinWidth,
					alignment: .leading
				)
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(1)
				.accessibilityElement(children: .combine)
		}
	}
}
