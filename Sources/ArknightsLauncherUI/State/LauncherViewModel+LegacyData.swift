// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

extension LauncherViewModel {
	/// Runs after the user confirms deletion from the pre-0.6 notice.
	func confirmDeleteLegacyData(failureID: UUID) {
		guard
			let failure = lifecycle.state.presentation.failure,
			failure.id == failureID,
			failure.actions.contains(.deleteDataFolder),
			!failure.isBusy
		else { return }
		startLegacyDataDeletion(failure: failure)
	}

	func retryLegacyDataDeletion(failureID: UUID) -> Bool {
		guard
			let failure = lifecycle.state.presentation.failure,
			failure.id == failureID,
			failure.actions.contains(.tryAgain),
			!failure.isBusy
		else { return false }
		startLegacyDataDeletion(failure: failure)
		return true
	}

	private func startLegacyDataDeletion(failure: LauncherFailurePresentation) {
		guard legacyDataDeletionTask == nil else { return }
		let failureID = failure.id
		lifecycle.restoreFailure(
			LauncherFailurePresentation(
				id: failure.id,
				title: failure.title,
				message: "Deleting old launcher data…",
				code: nil,
				context: failure.context,
				actions: failure.actions,
				blocksGameLaunch: true,
				showsDismissAction: false,
				isBusy: true
			))
		legacyDataDeletionTask = Task { [paths, preferences] in
			do {
				try await Self.deleteLegacyData(paths: paths)
			} catch {
				legacyDataDeletionTask = nil
				presentLegacyDataDeletionFailure(error, id: failureID)
				return
			}
			LegacyDataEraser.removeInstallPathKeys(userDefaults: preferences.defaults)
			legacyDataDeletionTask = nil
			lifecycle.clearFailure()
			installation.reloadInstallDirectory()
			_ = await completeStartupAfterLegacyDataDeletion()
		}
	}

	@concurrent
	private static func deleteLegacyData(paths: AppPaths) async throws {
		try LegacyDataEraser.erase(paths: paths)
		try LayoutMigrator.writeFreshLayout(paths: paths)
	}

	private func presentLegacyDataDeletionFailure(_ error: any Error, id: UUID) {
		let failure = LauncherFailurePresentation(
			id: id,
			title: "Data from an old launcher version",
			message: "The launcher could not delete the old data. \(error.localizedDescription)",
			code: nil,
			context: SupportContext(operation: .launcher, region: nil),
			actions: [.tryAgain, .quit],
			blocksGameLaunch: true,
			showsDismissAction: false
		)
		lifecycle.restoreFailure(failure)
		log.error(
			"Legacy data deletion failed: \(launcherDiagnosticDescription(for: error))")
	}
}
