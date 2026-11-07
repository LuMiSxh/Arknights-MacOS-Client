// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import Foundation

extension GameSessionController {
	package func refreshRuntime() {
		if let diagnostic = paths.runtimeLaneDiagnostic {
			log.error(diagnostic)
		}
		do {
			let runtime = try discoverRuntime()
			runtimeName = runtime.displayName
			metalFXSpatialUpscalingSupported = runtime.features.metalFXSpatialUpscaling
			installedRuntime = InstalledRuntimeDetails(
				name: runtime.displayName,
				pins: runtime.pins,
				features: runtime.features,
				architecture: runtime.runtimeArchitecture
			)
		} catch {
			runtimeName = nil
			metalFXSpatialUpscalingSupported = false
			installedRuntime = nil
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
		lifecycle.presentFailure(
			error,
			id: id,
			code: .runtimeSetupFailed,
			context: SupportContext(
				operation: operation,
				region: region.supportRegion
			),
			canRepair: false,
			blocksGameLaunch: false
		)
	}

	func discoverRuntime() throws -> WineRuntime {
		try Self.discoverRuntime(paths: paths, compatibilityManager: gameCompatibilityManager)
	}

	nonisolated static func discoverRuntime(
		paths: AppPaths,
		compatibilityManager: GameCompatibilityManager
	) throws -> WineRuntime {
		guard let configurationURL = paths.activeRuntimeConfigurationURL() else {
			throw WineRuntimeDiscoveryError.missingRuntime(
				paths.runtimeDirectory(for: paths.runtimeLane))
		}
		return try WineRuntime.discover(
			runtimeRoot: configurationURL.deletingLastPathComponent(),
			configurationURL: configurationURL,
			compatibilityManager: compatibilityManager
		)
	}
}
