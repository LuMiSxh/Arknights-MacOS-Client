// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

/// A running download on every setup step. Both the game and the runtime download can pause and
/// resume from their partial files. Back never cancels either one.
struct OnboardingRailDownload: View {
	let installation: InstallationController
	let runtimeSelection: RuntimeSelectionController
	let lifecycle: LauncherLifecycleStore
	let pause: () -> Void
	let pauseRuntime: () -> Void
	let resumeRuntime: () -> Void
	let resume: () -> Void
	let retry: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.content) {
			if runtimeSelection.isInstalling {
				RuntimeDownloadProgress(controller: runtimeSelection, pause: pauseRuntime)
			} else if runtimeSelection.pausedLane != nil {
				PausedDownload(title: "Runtime download paused", resume: resumeRuntime)
			}
			if installation.isDownloading {
				GameDownloadProgress(installation: installation, pause: pause)
			} else if let failure = gameFailure {
				FailedGameDownload(code: failure.code, retry: retry)
			} else if showsResume {
				PausedDownload(title: "Download paused", resume: resume)
			}
		}
	}

	// The Home failure sheet waits while setup is visible, so the rail shows the failure on every step.
	private var gameFailure: LauncherFailurePresentation? {
		lifecycle.state.presentation.failure.flatMap { $0.isGameDownloadFailure ? $0 : nil }
	}

	private var showsResume: Bool {
		installation.hasPartialDownload && !installation.isInstalled && installation.canInstall
	}
}

// Only this leaf reads the per-tick game progress, so the rail does not redraw on every update.
private struct GameDownloadProgress: View {
	let installation: InstallationController
	let pause: () -> Void
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
			Text(isPausing ? "Pausing download" : "Downloading game files")
				.font(.caption.weight(.medium))
				.foregroundStyle(theme.textPrimary)
			if let progress = installation.progress {
				ProgressView(value: progress.fraction)
					.tint(theme.accentFill)
				Text(progress.transferSummary)
					.font(.caption2.monospacedDigit())
					.foregroundStyle(theme.textSecondary)
			} else {
				ProgressView()
					.controlSize(.small)
			}
			CapsuleActionButton(
				title: "Pause",
				systemImage: "pause.fill",
				tone: .neutral,
				presentation: .compact,
				action: pause
			)
			.disabled(isPausing)
		}
	}

	private var isPausing: Bool {
		if case .installing(_, .pausing) = installation.lifecycle.activity { return true }
		return false
	}
}

private struct PausedDownload: View {
	let title: String
	let resume: () -> Void
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
			Text(title)
				.font(.caption.weight(.medium))
				.foregroundStyle(theme.textPrimary)
			CapsuleActionButton(
				title: "Resume",
				systemImage: "play.fill",
				tone: .accent,
				presentation: .compact,
				action: resume
			)
		}
	}
}

private struct FailedGameDownload: View {
	let code: SupportCode?
	let retry: () -> Void
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
			Text("Download failed")
				.font(.caption.weight(.medium))
				.foregroundStyle(theme.dangerText)
			if let code {
				Text(code.rawValue)
					.font(.caption2.monospaced())
					.foregroundStyle(theme.textSecondary)
					.textSelection(.enabled)
			}
			CapsuleActionButton(
				title: "Retry",
				systemImage: "arrow.clockwise",
				tone: .warning,
				presentation: .compact,
				action: retry
			)
		}
	}
}

// Only this leaf reads the per-tick runtime progress.
private struct RuntimeDownloadProgress: View {
	let controller: RuntimeSelectionController
	let pause: () -> Void
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
			Text("Installing runtime")
				.font(.caption.weight(.medium))
				.foregroundStyle(theme.textPrimary)
			if let fraction = controller.installFraction {
				ProgressView(value: fraction)
					.tint(theme.accentFill)
			} else {
				ProgressView()
					.controlSize(.small)
			}
			// Only the download phase can pause. Extraction and validation run to the end.
			if controller.installProgress == nil
				|| controller.installProgress?.phase == .downloading
			{
				CapsuleActionButton(
					title: "Pause",
					systemImage: "pause.fill",
					tone: .neutral,
					presentation: .compact,
					action: pause
				)
			}
		}
	}
}
