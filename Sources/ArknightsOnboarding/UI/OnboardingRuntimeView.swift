// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import Foundation
import SwiftUI

struct OnboardingRuntimeView: View {
	let runtimeSelection: RuntimeSelectionController
	@Binding var selectedLane: RuntimeLane?
	let isDisabled: Bool
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		OnboardingPage(
			title: "Runtime",
			subtitle:
				"The runtime runs the game on this Mac. You can change it later in Settings."
		) {
			OnboardingQuestion(
				question: "Choose a runtime",
				answers: answers,
				selection: $selectedLane,
				isDisabled: isDisabled,
				footnote: footnote
			)

			QuietLink(title: "About game runtimes", destination: SupportLinks.runtimeGuide)
				.font(.callout)
				.padding(.horizontal, LauncherTokens.Spacing.panel)

			if runtimeSelection.isInstalling {
				RuntimeProgressPanel(controller: runtimeSelection)
			}

			if let failure = runtimeSelection.failure {
				failurePanel(failure)
			}

		}
	}

	private var answers: [OnboardingAnswer<RuntimeLane>] {
		runtimeSelection.availableLanes.map { lane in
			OnboardingAnswer(
				value: lane,
				title: lane == .x86 ? "x86_64" : "ARM64 (Apple Silicon)",
				detail: laneDetail(lane),
				systemImage: lane == .x86 ? "cpu" : "apple.logo",
				isRecommended: lane == .arm
			)
		}
	}

	private var footnote: String? {
		if !runtimeSelection.allowsX86 {
			return "x86_64 requires macOS 27 or earlier."
		}
		if !runtimeSelection.allowsARM64 {
			return "ARM64 requires macOS 26 or later."
		}
		if !runtimeSelection.availableLanes.contains(.arm) {
			return "ARM64 is not available in this launcher release."
		}
		return nil
	}

	private func failurePanel(_ failure: RuntimeSelectionFailure) -> some View {
		SettingsPanel(title: "Runtime setup failed", tone: .warning) {
			VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
				Text(failure.message)
					.font(.callout)
					.foregroundStyle(theme.textPrimary)
					.fixedSize(horizontal: false, vertical: true)
				if let code = failure.code {
					HStack(spacing: LauncherTokens.Spacing.compact) {
						Text("Support code")
							.foregroundStyle(theme.textSecondary)
						Text(code.rawValue)
							.font(.callout.monospaced())
							.foregroundStyle(theme.dangerText)
							.textSelection(.enabled)
					}
					.font(.caption)
				}
			}
			.padding(.vertical, LauncherTokens.Spacing.compact)
		}
	}

	private func laneDetail(_ lane: RuntimeLane) -> String {
		"\(lane.summary) \(laneInfo(lane))"
	}

	private func laneInfo(_ lane: RuntimeLane) -> String {
		var parts: [String] = []
		if let version = runtimeSelection.installedVersion(for: lane) {
			parts.append("Installed, version \(version)")
		} else {
			parts.append("Not installed")
		}
		guard let pin = runtimeSelection.pinnedRuntime(for: lane) else {
			return parts.joined(separator: " · ")
		}
		if runtimeSelection.installedVersion(for: lane) == nil {
			parts.append("Version \(pin.version)")
		}
		parts.append(
			"\(ByteCountFormatter.string(fromByteCount: Int64(pin.sizeBytes), countStyle: .file)) download"
		)
		parts.append("Requires \(macOSVersion(pin.minimumMacOS)) or later")
		return parts.joined(separator: " · ")
	}

	private func macOSVersion(_ version: OperatingSystemVersion) -> String {
		version.minorVersion == 0
			? "macOS \(version.majorVersion)"
			: "macOS \(version.majorVersion).\(version.minorVersion)"
	}
}

// Only this leaf reads the per-tick runtime progress, so the setup step does not re-render on
// every update.
private struct RuntimeProgressPanel: View {
	let controller: RuntimeSelectionController
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		SettingsPanel(title: "Download") {
			VStack(alignment: .leading, spacing: LauncherTokens.Spacing.content) {
				Text(title)
					.fontWeight(.medium)
				if let fraction = controller.installFraction {
					ProgressView(value: fraction)
						.tint(theme.accentFill)
				} else {
					ProgressView()
						.controlSize(.small)
				}
				if let detail {
					Text(detail)
						.font(.caption.monospacedDigit())
						.foregroundStyle(theme.textSecondary)
				}
			}
			.padding(.vertical, LauncherTokens.Spacing.compact)
		}
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
