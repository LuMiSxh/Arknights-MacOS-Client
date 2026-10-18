// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
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
	package let lifecycle: LauncherLifecycleStore
	package let installation: InstallationController

	var body: some View {
		let status = lifecycle.state.presentation.status
		let progress = installation.progress
		if let text = SettingsOperationStripPresentation.text(status: status, progress: progress) {
			Text(text)
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(1)
				.truncationMode(.tail)
				.frame(maxWidth: .infinity, alignment: .leading)
				.accessibilityElement(children: .ignore)
				.accessibilityLabel(
					Text(SettingsOperationStripPresentation.accessibilityLabel(for: status) ?? text)
				)
				.accessibilityValue(
					Text(
						SettingsOperationStripPresentation.accessibilityValue(
							status: status, progress: progress)))
		}
	}
}
