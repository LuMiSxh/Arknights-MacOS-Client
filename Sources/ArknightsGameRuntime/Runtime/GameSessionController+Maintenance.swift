// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

extension GameSessionController {
	package func refreshRuntime() {
		do {
			let runtime = try discoverRuntime()
			runtimeName = runtime.displayName
			// Settings needs the capability before the first launch, so read it once at startup.
			capabilitySlot.replace { [weak self] token in
				let discovery = await runtime.discoverCapabilities()
				guard let self, self.capabilitySlot.owns(token) else { return }
				self.metalFXSpatialUpscalingSupported =
					discovery.capabilities.metalFXSpatialUpscalingSupported
				if let diagnostic = discovery.diagnostic {
					self.log.info("Runtime capability fallback: \(diagnostic)")
				}
			}
		} catch {
			runtimeName = nil
			capabilitySlot.invalidate()
			metalFXSpatialUpscalingSupported = false
			log.error("Runtime discovery failed: \(error.localizedDescription)")
		}
	}

	package func forcePrefixMigration() {
		guard lifecycle.activity == .idle else { return }
		let operationID = UUID()
		let region = installation.region
		let prefixDirectory = paths.winePrefix(for: region)
		do {
			try RuntimeMigrationStore().reset(prefixDirectory: prefixDirectory)
			lifecycle.setStatus(.winePrefixResetScheduled)
			log.info("Wine prefix migration state was reset on request")
		} catch {
			presentRuntimeMaintenanceFailure(
				error,
				id: operationID,
				operation: .prefixMigration,
				region: region
			)
		}
	}

	@concurrent
	private static func removeWinePrefix(at directory: URL) async throws {
		try FileManager.default.removeItem(at: directory)
	}

	package func deleteWinePrefix() {
		guard lifecycle.activity == .idle else { return }
		let region = installation.region
		let prefixDirectory = paths.winePrefix(for: region)
		guard FileManager.default.fileExists(atPath: prefixDirectory.path) else { return }
		let operationID = UUID()
		guard let lease = lifecycle.begin(.maintaining(.deletingWinePrefix)) else { return }
		lifecycle.setStatus(.deletingWinePrefix)
		Task { [weak self] in
			guard let self else { return }
			do {
				try await Self.removeWinePrefix(at: prefixDirectory)
				lifecycle.end(lease)
				lifecycle.setStatus(.winePrefixDeleted)
				log.info("Wine prefix deleted on request")
			} catch {
				lifecycle.end(lease)
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
				code: .runtimeSetupFailed,
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
