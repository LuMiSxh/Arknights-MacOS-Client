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
			log.warning(.diagnostics, "install-state-skipped", error: error)
		}
		var migrations: DiagnosticsEnvironment.PrefixMigrations?
		do {
			migrations = try await PrefixMigrationSummary.read(prefixDirectory: prefixDirectory)
		} catch {
			log.warning(.diagnostics, "prefix-migrations-skipped", error: error)
		}

		let installedVersions = Dictionary(
			uniqueKeysWithValues: RuntimeLane.allCases.compactMap { lane in
				runtimeSelection.installedVersion(for: lane).map { (lane.rawValue, $0) }
			})
		let recentFailures = await Self.launcherFailures(
			current: paths.launcherLogFile,
			previous: AppPaths.previousLogFile(of: paths.launcherLogFile),
			log: log
		)
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
				options: settings.launchOptions, usesHardwareCursor: settings.usesHardwareCursor),
			recentFailures: recentFailures
		)
	}

	/// The failures the launcher presented, from the previous and current session logs.
	@concurrent
	private static func launcherFailures(
		current: URL, previous: URL, log: LauncherLog
	) async -> [DiagnosticsEnvironment.Failure] {
		let text = logText(at: previous, log: log) + logText(at: current, log: log)
		return LogFailureParser.failures(inLogText: text)
	}

	/// A missing log file is empty; any other read failure is logged and treated as empty.
	private nonisolated static func logText(at url: URL, log: LauncherLog) -> String {
		do {
			return try String(contentsOf: url, encoding: .utf8)
		} catch  where AppPaths.isMissingPathError(error) {
			return ""
		} catch {
			log.warning(
				.diagnostics, "launcher-log-read-skipped",
				["file": url.lastPathComponent], error: error)
			return ""
		}
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
