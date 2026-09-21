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
		let region = installation.region
		let prefixDirectory = paths.winePrefix(for: region)
		do {
			try RuntimeMigrationStore().reset(prefixDirectory: prefixDirectory)
			lifecycle.setStatus(
				.custom("Wine setup will run again on next launch"))
			Task { [log] in
				await log.info("Wine prefix migration state was reset on request")
			}
		} catch {
			presentRuntimeMaintenanceFailure(
				error,
				id: operationID,
				operation: .prefixMigration,
				region: region
			)
		}
	}

	func deleteWinePrefix() {
		guard lifecycle.activity == .idle else { return }
		let region = installation.region
		let prefixDirectory = paths.winePrefix(for: region)
		guard FileManager.default.fileExists(atPath: prefixDirectory.path) else { return }
		let operationID = UUID()
		lifecycle.activity = .maintaining(.deletingWinePrefix)
		lifecycle.setStatus(
			.custom("Deleting Wine prefix…"))
		Task { [weak self] in
			guard let self else { return }
			do {
				try await Task.detached(priority: .userInitiated) {
					try FileManager.default.removeItem(at: prefixDirectory)
				}.value
				lifecycle.activity = .idle
				lifecycle.setStatus(
					.custom("Wine prefix deleted; setup will run again on next launch"))
				await log.info("Wine prefix deleted on request")
			} catch {
				lifecycle.activity = .idle
				presentRuntimeMaintenanceFailure(
					error,
					id: operationID,
					operation: .prefixDeletion,
					region: region
				)
			}
		}
	}

	private func presentRuntimeMaintenanceFailure(
		_ error: any Error,
		id: UUID,
		operation: SupportOperation,
		region: GameRegion
	) {
		let message = launcherUserMessage(for: error)
		lifecycle.presentFailure(
			LauncherFailurePresentation(
				id: id,
				message: message,
				code: .sepia,
				context: SupportContext(
					operation: operation,
					region: region.supportRegion
				),
				actions: [.retry, .openTroubleshooting, .reportProblem]
			),
			diagnostic: launcherDiagnosticDescription(for: error)
		)
	}

	func discoverRuntime() throws -> WineRuntime {
		try WineRuntime.discover(compatibilityManager: gameCompatibilityManager)
	}
}
