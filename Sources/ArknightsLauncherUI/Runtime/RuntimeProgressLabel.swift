// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

/// Shows runtime install progress. Only this leaf reads the per-tick progress, so the parent
/// views do not re-render on every update.
struct RuntimeProgressLabel: View {
	let controller: RuntimeSelectionController
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.compact) {
			Text(title)
				.font(LauncherTokens.Typography.statusTitle)
			if let fraction = controller.installFraction {
				ProgressView(value: fraction)
					.tint(theme.accentFill)
					.accessibilityHidden(true)
			} else {
				ProgressView()
					.controlSize(.small)
					.accessibilityHidden(true)
			}
			if let detail {
				Text(detail)
					.font(.caption.monospacedDigit())
					.foregroundStyle(theme.textSecondary)
			}
		}
		.accessibilityElement(children: .combine)
		.accessibilityLabel(Text(title))
		.accessibilityValue(Text(detail ?? ""))
	}

	private var title: String {
		RuntimeInstallPresentation.phaseTitle(for: controller.installProgress)
	}

	private var detail: String? {
		RuntimeInstallPresentation.detail(for: controller.installProgress)
	}
}

/// Pause for a runtime download. Only this leaf reads the per-tick phase. Shows in the download
/// phase only, matching the controller, which cannot pause extraction.
struct RuntimePauseButton: View {
	let controller: RuntimeSelectionController
	let pause: () -> Void

	var body: some View {
		if showsPause {
			CapsuleActionButton(
				title: "Pause",
				systemImage: "pause.fill",
				tone: .neutral,
				presentation: .compact,
				action: pause
			)
		}
	}

	private var showsPause: Bool {
		controller.installProgress.map { $0.phase == .downloading } ?? true
	}
}

/// Home status line for a runtime install. Only this leaf reads the per-tick progress, so the
/// parent views do not re-render on every update.
struct RuntimeDownloadStatusLabel: View {
	let controller: RuntimeSelectionController

	var body: some View {
		let progress = controller.installProgress
		DownloadStatusLine(
			title: RuntimeInstallPresentation.title(for: progress),
			widestTitle: RuntimeInstallPresentation.widestTitle(for: progress),
			detail: RuntimeInstallPresentation.detail(for: progress),
			rate: RuntimeInstallPresentation.transferDetail(for: progress),
			accessibilityValue: RuntimeInstallPresentation.accessibilityValue(for: progress)
		)
	}
}

/// Copy and progress for a runtime install, matching the game download line.
enum RuntimeInstallPresentation {
	static func phaseTitle(for progress: RuntimeInstallProgress?) -> String {
		guard let progress else { return "Preparing runtime…" }
		return switch progress.phase {
		case .downloading: "Downloading runtime…"
		case .extracting: "Extracting runtime…"
		case .validating: "Verifying runtime…"
		case .installing: "Installing runtime…"
		}
	}

	static func title(for progress: RuntimeInstallProgress?) -> String {
		let phaseTitle = phaseTitle(for: progress)
		guard let percentage = percentage(for: progress) else { return phaseTitle }
		return "\(phaseTitle) · \(percentage)%"
	}

	static func widestTitle(for progress: RuntimeInstallProgress?) -> String {
		let phaseTitle = phaseTitle(for: progress)
		return percentage(for: progress) == nil ? phaseTitle : "\(phaseTitle) · 100%"
	}

	static func detail(for progress: RuntimeInstallProgress?) -> String? {
		guard let progress, progress.phase == .downloading, progress.totalBytes > 0 else {
			return nil
		}
		return DownloadProgressFormatting.transferSummary(
			downloadedBytes: progress.downloadedBytes,
			totalBytes: progress.totalBytes
		)
	}

	static func transferDetail(for progress: RuntimeInstallProgress?) -> String? {
		guard let progress, progress.phase == .downloading else { return nil }
		if let rate = progress.transferRateBytesPerSecond {
			return DownloadProgressFormatting.byteRate(rate)
		}
		if progress.isTransferStalled { return "Waiting for network…" }
		return nil
	}

	static func accessibilityValue(for progress: RuntimeInstallProgress?) -> String {
		[detail(for: progress), transferDetail(for: progress)]
			.compactMap { $0 }
			.joined(separator: ", ")
	}

	/// The HUD outline follows the game: a byte fraction while downloading, and a full
	/// indeterminate rail while the installer extracts, verifies, or installs.
	static func outlineFraction(for progress: RuntimeInstallProgress?) -> Double? {
		guard let progress else { return nil }
		switch progress.phase {
		case .downloading:
			return progress.totalBytes > 0 ? downloadFraction(for: progress) : nil
		case .extracting, .validating, .installing:
			return 1
		}
	}

	static func showsActiveProgressEffect(for progress: RuntimeInstallProgress?) -> Bool {
		guard let progress else { return false }
		switch progress.phase {
		case .downloading:
			guard progress.totalBytes > 0, !progress.isTransferStalled else { return false }
			let fraction = downloadFraction(for: progress)
			return fraction > 0 && fraction < 1
		case .extracting, .validating, .installing:
			return true
		}
	}

	private static func percentage(for progress: RuntimeInstallProgress?) -> Int? {
		guard let progress, progress.phase == .downloading, progress.totalBytes > 0 else {
			return nil
		}
		return Int(downloadFraction(for: progress) * 100)
	}

	private static func downloadFraction(for progress: RuntimeInstallProgress) -> Double {
		min(max(Double(progress.downloadedBytes) / Double(progress.totalBytes), 0), 1)
	}
}

extension RuntimeLane {
	/// Full lane name for headings and rows.
	var title: String {
		self == .x86 ? "x86_64" : "ARM64 (Apple Silicon)"
	}

	/// Short lane name for sentences.
	var shortLabel: String {
		self == .x86 ? "x86_64" : "ARM64"
	}
}
