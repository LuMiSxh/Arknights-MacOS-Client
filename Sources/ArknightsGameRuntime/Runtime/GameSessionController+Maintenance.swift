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
		let prefixDirectory = paths.winePrefix(for: region, lane: currentRuntimeLane())
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
		let prefixDirectory = paths.winePrefix(for: region, lane: currentRuntimeLane())
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
		try Self.discoverRuntime(
			paths: paths,
			lane: currentRuntimeLane(),
			compatibilityManager: gameCompatibilityManager)
	}

	nonisolated static func discoverRuntime(
		paths: AppPaths,
		lane: RuntimeLane,
		compatibilityManager: GameCompatibilityManager
	) throws -> WineRuntime {
		try discoverRuntime(
			paths: paths,
			lane: lane,
			configuration: RuntimeConfiguration.bundled(),
			compatibilityManager: compatibilityManager
		)
	}

	nonisolated static func discoverRuntime(
		paths: AppPaths,
		lane: RuntimeLane,
		configuration: RuntimeConfiguration,
		compatibilityManager: GameCompatibilityManager
	) throws -> WineRuntime {
		let versionDirectory = try pinnedRuntimeVersionDirectory(
			paths: paths, lane: lane, configuration: configuration)
		let configurationURL = versionDirectory.appending(path: "RUNTIME.json")
		guard FileManager.default.fileExists(atPath: configurationURL.path) else {
			throw WineRuntimeDiscoveryError.missingRuntime(versionDirectory)
		}
		return try WineRuntime.discover(
			runtimeRoot: versionDirectory,
			configurationURL: configurationURL,
			compatibilityManager: compatibilityManager
		)
	}

	/// Launch uses only the pinned version directory. Falling back to another installed version
	/// would run a runtime that the launcher release does not support.
	nonisolated static func pinnedRuntimeVersionDirectory(
		paths: AppPaths,
		lane: RuntimeLane,
		configuration: RuntimeConfiguration
	) throws -> URL {
		let pin = try configuration.pinnedRuntime(for: lane)
		return paths.runtimeVersionDirectory(for: lane, version: pin.version)
	}
}
