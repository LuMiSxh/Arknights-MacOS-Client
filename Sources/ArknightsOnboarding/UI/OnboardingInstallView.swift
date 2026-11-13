// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import Foundation
import SwiftUI

// The one step that downloads: the runtime, then the game files location, then Rosetta 2 for the
// x86_64 runtime. The server is already chosen, so the page names it before anything downloads.
struct OnboardingInstallView: View {
	let installation: InstallationController
	let lifecycle: LauncherLifecycleStore
	let runtimeSelection: RuntimeSelectionController
	@Binding var selectedLane: RuntimeLane?
	let isDisabled: Bool
	let intelTranslationState: IntelTranslationState
	let rosettaInstallationState: RosettaInstallationState
	let chooseInstallDirectory: () -> Void
	let locateExistingInstallation: () -> Void
	let retryIntelTranslation: () -> Void
	let installRosetta: () -> Void

	var body: some View {
		OnboardingPage(
			step: .install,
			subtitle:
				"Set up the runtime and game files for \(installation.region.displayName) from \(installation.region.publisherName)"
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
				InlineFailureView(message: failure.message, code: failure.code)
					.padding(.horizontal, LauncherTokens.Spacing.panel)
			}

			OnboardingGameFilesPanel(
				installation: installation,
				lifecycle: lifecycle,
				chooseInstallDirectory: chooseInstallDirectory,
				locateExistingInstallation: locateExistingInstallation
			)

			if selectedLane == .x86 {
				OnboardingRosettaPanel(
					intelTranslationState: intelTranslationState,
					rosettaInstallationState: rosettaInstallationState,
					rosettaFailureCode: lifecycle.state.presentation.failure.flatMap {
						$0.context.operation == .rosettaInstallation ? $0.code : nil
					},
					retryIntelTranslation: retryIntelTranslation,
					installRosetta: installRosetta
				)
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
