// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import Foundation

extension LauncherViewModel {
	/// Gathers the `environment.json` facts from the feature controllers and local files.
	///
	/// Nothing here touches the network. A fact that cannot be read is logged and left out.
	func diagnosticsEnvironment() async -> DiagnosticsEnvironment {
		let region = installation.region
		let lane = runtimeSelection.selectedLane
		let installDirectory = installation.installDirectory
		let prefixDirectory = paths.winePrefix(for: region, lane: lane)
		let log = log

		var installState: DiagnosticsEnvironment.InstallState?
		do {
			installState = try await InstalledStateSummary.read(in: installDirectory)
		} catch {
			log.error("Install state skipped: \(launcherDiagnosticDescription(for: error))")
		}
		var migrations: DiagnosticsEnvironment.PrefixMigrations?
		do {
			migrations = try await PrefixMigrationSummary.read(prefixDirectory: prefixDirectory)
		} catch {
			log.error("Prefix migrations skipped: \(launcherDiagnosticDescription(for: error))")
		}

		let installedVersions = Dictionary(
			uniqueKeysWithValues: RuntimeLane.allCases.compactMap { lane in
				runtimeSelection.installedVersion(for: lane).map { (lane.rawValue, $0) }
			})
		return DiagnosticsEnvironment(
			app: .current(),
			system: .current(
				rosetta: lifecycle.state.readiness.intelTranslation.diagnosticName,
				displays: GameScreenList.system().screens.map(\.diagnosticsDisplay)),
			runtime: .init(
				selectedLane: lane.rawValue,
				name: gameSession.runtimeName,
				installedVersions: installedVersions,
				metalFXSpatialUpscaling: gameSession.metalFXSpatialUpscalingSupported.map {
					$0 ? "supported" : "unsupported"
				} ?? "unknown",
				pinnedPrefixRevision: runtimeSelection.pinnedRuntime(for: lane)?.prefixRevision,
				prefixMigrations: migrations),
			game: .init(
				server: region.rawValue,
				installedVersion: installation.installedVersion,
				latestKnownVersion: installation.configuration?.gameLatestVersion,
				updateAvailable: installation.isGameUpdateAvailable,
				installLocation: installDirectory.standardizedFileURL
					== paths.gameInstall(for: region).standardizedFileURL ? "managed" : "custom",
				volume: .containing(installDirectory),
				installState: installState,
				installedServers: installation.installedRegions.map(\.rawValue).sorted()),
			settings: .init(
				options: settings.launchOptions, usesHardwareCursor: settings.usesHardwareCursor)
		)
	}

	/// The install folder of every server, managed or located, for the game folder logs.
	func gameDirectories() -> [(region: GameRegion, directory: URL)] {
		GameRegion.allCases.map {
			(
				$0,
				preferences.installDirectory(for: $0, default: paths.gameInstall(for: $0))
			)
		}
	}
}
