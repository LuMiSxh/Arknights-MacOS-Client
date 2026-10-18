// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

struct LauncherActivityStatusView: View {
	package let lifecycle: LauncherLifecycleStore
	package let installation: InstallationController
	package let accentColor: Color
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var completionFeedback: InstallationCompletionFeedback?

	var body: some View {
		Group {
			if let completionFeedback, showsCompletionFeedback {
				HStack(spacing: 6) {
					LauncherCompletionFeedbackView(feedbackID: completionFeedback.id)
					Text("Installation complete")
				}
				.font(LauncherVisuals.Typography.statusTitle)
				.accessibilityElement(children: .combine)
				.accessibilityLabel(Text("Installation complete"))
			} else if showsDownloadLayout {
				DownloadStatusLabel(
					lifecycle: lifecycle,
					installation: installation,
					isPausedDownload: isPausedDownload
				)
			} else {
				PlainStatusText(title: statusTitle)
			}
		}
		.onAppear(perform: consumeCompletionFeedback)
		.onChange(of: installation.completionFeedback?.id) { _, _ in
			consumeCompletionFeedback()
		}
		.onChange(of: lifecycle.state.presentation.failure?.id) { _, failureID in
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
				try await Task.sleep(for: LauncherMotion.Cycle.completionFeedback)
			} catch {
				return
			}
			guard !Task.isCancelled,
				completionFeedback == displayedFeedback,
				displayedFeedback.region == installation.region,
				lifecycle.activity == .idle,
				lifecycle.state.presentation.failure == nil
			else {
				completionFeedback = nil
				return
			}
			completionFeedback = nil
			consumeCompletionFeedback()
		}
	}

	private var showsCompletionFeedback: Bool {
		guard let completionFeedback else { return false }
		return completionFeedback.region == installation.region
			&& lifecycle.activity == .idle
			&& lifecycle.state.presentation.failure == nil
	}

	private func consumeCompletionFeedback() {
		guard completionFeedback == nil else { return }
		completionFeedback = installation.consumeCompletionFeedback(for: installation.region)
	}

	private var statusTitle: String {
		if lifecycle.state.presentation.failure?.blocksGameLaunch == true {
			return "Needs attention"
		}
		return lifecycle.state.presentation.status.message
	}

	private var isPausedDownload: Bool {
		lifecycle.state.presentation.status == .paused
			&& installation.hasPartialDownload
			&& lifecycle.state.presentation.failure == nil
	}

	// Decided by state only so the parent does not re-render on each progress tick.
	private var showsDownloadLayout: Bool {
		guard lifecycle.state.presentation.failure == nil else { return false }
		return lifecycle.state.presentation.status == .downloading
			|| lifecycle.state.presentation.status == .verifyingInstallation
			|| isPausedDownload
	}
}

private struct PlainStatusText: View {
	let title: String

	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(title)
				.font(LauncherVisuals.Typography.statusTitle)
				.contentTransition(.opacity)
		}
	}
}

// Only this leaf reads per-tick progress, so the parent does not re-render on each update.
private struct DownloadStatusLabel: View {
	let lifecycle: LauncherLifecycleStore
	let installation: InstallationController
	let isPausedDownload: Bool
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		if showsDownloadSnapshot {
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
			PlainStatusText(title: statusTitle)
		}
	}

	private var statusTitle: String {
		if showsDownloadSnapshot,
			let title = LauncherDownloadProgressPresentation.title(
				for: installation.progress,
				isPaused: isPausedDownload
			)
		{
			return title
		}
		return lifecycle.state.presentation.status.message
	}

	private var statusDetail: String? {
		if let progress = installation.progress, progress.totalBytes > 0 {
			let downloaded = DownloadProgressFormatting.byteCount(progress.downloadedBytes)
			let total = DownloadProgressFormatting.byteCount(progress.totalBytes)
			return "\(downloaded) of \(total)"
		}
		return nil
	}

	private var accessibilityProgressValue: String {
		LauncherDownloadProgressPresentation.accessibilityValue(
			for: installation.progress,
			detail: statusDetail,
			isPaused: isPausedDownload
		)
	}

	private var showsDownloadSnapshot: Bool {
		lifecycle.state.presentation.status == .downloading
			|| (lifecycle.state.presentation.status == .verifyingInstallation
				&& installation.progress?.isVerifying == true)
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
		ZStack(alignment: .leading) {
			Text(
				LauncherDownloadProgressPresentation.widestTitle(
					isVerifying: installation.progress?.isVerifying == true,
					isPaused: isPausedDownload
				)
			)
			.font(LauncherVisuals.Typography.statusPercent)
			.monospacedDigit()
			.hidden()
			.accessibilityHidden(true)
			Text(statusTitle)
				.font(LauncherVisuals.Typography.statusPercent)
				.monospacedDigit()
				.contentTransition(reduceMotion ? .identity : .numericText())
				.animation(
					LauncherMotion.animation(.state, reduceMotion: reduceMotion),
					value: statusTitle
				)
				.fixedSize(horizontal: true, vertical: false)
		}
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
