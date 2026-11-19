// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

enum SettingsOperationStripPresentation {
	// The strip text, or `nil` when no work is active and the strip stays hidden.
	static func text(status: LauncherStatus, progress: DownloadProgress?) -> String? {
		if let title = downloadTitle(status: status, progress: progress) { return title }
		return label(for: status)
	}

	static func accessibilityLabel(for status: LauncherStatus) -> String? {
		label(for: status)
	}

	static func accessibilityValue(status: LauncherStatus, progress: DownloadProgress?) -> String {
		percentage(status: status, progress: progress)
			.map { "\($0) percent" } ?? ""
	}

	private static func label(for status: LauncherStatus) -> String? {
		switch status {
		case .checking, .preparingInstallation, .verifyingInstallation, .downloading, .pausing,
			.paused, .preparingWine, .startingGame, .stoppingGame, .movingToTrash,
			.migratingStorage, .deletingWinePrefix:
			status.message.trimmingCharacters(in: CharacterSet(charactersIn: "…"))
		case .ready, .updateAvailable, .install, .updated, .running, .uninstalled,
			.winePrefixDeleted, .winePrefixResetScheduled, .gameExecutableNotFound:
			nil
		}
	}

	// Download wording comes from the shared presentation so both surfaces show the same title.
	private static func downloadTitle(
		status: LauncherStatus,
		progress: DownloadProgress?
	) -> String? {
		switch status {
		case .downloading:
			LauncherDownloadProgressPresentation.labeledTitle(for: progress, isPaused: false)
		case .paused:
			LauncherDownloadProgressPresentation.title(for: progress, isPaused: true)
		case .verifyingInstallation:
			progress?.isVerifying == true
				? LauncherDownloadProgressPresentation.title(for: progress, isPaused: false) : nil
		default:
			nil
		}
	}

	private static func percentage(status: LauncherStatus, progress: DownloadProgress?) -> Int? {
		switch status {
		case .downloading, .pausing, .paused:
			LauncherDownloadProgressPresentation.percentage(for: progress)
		case .verifyingInstallation:
			progress?.isVerifying == true
				? LauncherDownloadProgressPresentation.percentage(for: progress) : nil
		default:
			nil
		}
	}
}

// Only this leaf reads the per-tick installation progress, so the rest of the sheet does not re-render on every update.
struct SettingsOperationStrip: View {
	@Environment(\.launcherTheme) private var theme
	let lifecycle: LauncherLifecycleStore
	let installation: InstallationController
	let runtimeSelection: RuntimeSelectionController

	var body: some View {
		let status = lifecycle.state.presentation.status
		let progress = installation.progress
		let gameText =
			SettingsOperationStripPresentation.text(status: status, progress: progress)
			?? lifecycle.activity.lockReason
		// A runtime install takes no lifecycle lease, so it needs its own branch.
		if runtimeSelection.isInstalling {
			line(text: RuntimeInstallPresentation.title(for: runtimeSelection.installProgress))
		} else if let text = gameText {
			line(
				text: text,
				label: SettingsOperationStripPresentation.accessibilityLabel(for: status) ?? text,
				value: SettingsOperationStripPresentation.accessibilityValue(
					status: status, progress: progress)
			)
		}
	}

	private func line(text: String, label: String? = nil, value: String = "") -> some View {
		Text(text)
			.font(.caption)
			.foregroundStyle(theme.textSecondary)
			.lineLimit(1)
			.truncationMode(.tail)
			.frame(maxWidth: .infinity, alignment: .leading)
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(Text(label ?? text))
			.accessibilityValue(Text(value))
	}
}
