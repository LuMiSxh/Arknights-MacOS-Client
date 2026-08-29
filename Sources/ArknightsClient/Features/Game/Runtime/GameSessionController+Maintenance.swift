// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameSessionController {
	func refreshRuntime() {
		do {
			runtimeName = try discoverRuntime().displayName
		} catch {
			runtimeName = nil
			Task { [log] in
				await log.error("Runtime discovery failed: \(error.localizedDescription)")
			}
		}
	}

	func forcePrefixMigration() {
		guard lifecycle.activity == .idle else { return }
		let operationID = UUID()
		do {
			try RuntimeMigrationStore().reset(prefixDirectory: paths.winePrefix)
			lifecycle.setStatus(
				.custom(L10n.string(.Launcher.launcherStatusWineMigrationPending)))
			Task { [log] in
				await log.info("Wine prefix migration state was reset on request")
			}
		} catch {
			presentRuntimeMaintenanceFailure(
				error,
				id: operationID,
				operation: .prefixMigration
			)
		}
	}

	func deleteWinePrefix() {
		guard lifecycle.activity == .idle else { return }
		let prefixDirectory = paths.winePrefix
		guard FileManager.default.fileExists(atPath: prefixDirectory.path) else { return }
		let operationID = UUID()
		lifecycle.activity = .maintaining(.deletingWinePrefix)
		lifecycle.setStatus(
			.custom(L10n.string(.Launcher.launcherStatusWinePrefixDeleting)))
		Task { [weak self] in
			guard let self else { return }
			do {
				try await Task.detached(priority: .userInitiated) {
					try FileManager.default.removeItem(at: prefixDirectory)
				}.value
				lifecycle.activity = .idle
				lifecycle.setStatus(
					.custom(L10n.string(.Launcher.launcherStatusWineMigrationDeleted)))
				await log.info("Wine prefix deleted on request")
			} catch {
				lifecycle.activity = .idle
				presentRuntimeMaintenanceFailure(
					error,
					id: operationID,
					operation: .prefixDeletion
				)
			}
		}
	}

	private func presentRuntimeMaintenanceFailure(
		_ error: any Error,
		id: UUID,
		operation: SupportOperation
	) {
		let message =
			(error as? any LocalizedError)?.errorDescription
			?? error.localizedDescription
		lifecycle.presentFailure(
			LauncherFailurePresentation(
				id: id,
				message: message,
				code: .sepia,
				context: SupportContext(operation: operation, region: nil),
				actions: [.retry, .openTroubleshooting, .reportProblem]
			),
			diagnostic: launcherDiagnosticDescription(for: error)
		)
	}

	func discoverRuntime() throws -> WineRuntime {
		try WineRuntime.discover(compatibilityManager: gameCompatibilityManager)
	}
}
