// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
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
		guard let progress = controller.installProgress else { return "Preparing runtime…" }
		return switch progress.phase {
		case .downloading: "Downloading runtime…"
		case .extracting: "Extracting runtime…"
		case .validating: "Verifying runtime…"
		case .installing: "Installing runtime…"
		}
	}

	private var detail: String? {
		guard let progress = controller.installProgress, progress.phase == .downloading,
			progress.totalBytes > 0
		else { return nil }
		return
			"\(ByteCountFormatter.string(fromByteCount: progress.downloadedBytes, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: progress.totalBytes, countStyle: .file))"
	}
}

extension RuntimeLane {
	/// Full lane name for headings and rows.
	var title: String {
		self == .x86 ? "x86_64 (recommended)" : "ARM64 (Apple Silicon)"
	}

	/// Short lane name for sentences.
	var shortLabel: String {
		self == .x86 ? "x86_64" : "ARM64"
	}
}
