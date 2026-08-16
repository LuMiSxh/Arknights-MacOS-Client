// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

extension LauncherViewModel {
	func launch() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.launching)
				return
			}
		#endif
		guard !isDownloading, !isGameActive else { return }
		let executable = installDirectory.appending(
			path: configuration?.executableName ?? "Arknights.exe")
		guard FileManager.default.fileExists(atPath: executable.path) else {
			show(LauncherError.gameNotInstalled(executable))
			return
		}
		guard let runtime = WineRuntime.discover() else {
			refreshRuntime()
			show(LauncherError.wineRuntimeMissing)
			return
		}

		phase = .launching
		activityMessage = "Starting…"
		let gameSessionID = UUID()
		let launchRequestedAt = Date()
		let displayConfiguration = WineDisplayConfiguration.current(
			highResolutionEnabled: launchOptions.usesHighResolutionMode
		)
		activeGameSessionID = gameSessionID
		Task { [log] in await log.info("Game launch requested") }
		launchTask?.cancel()
		launchTask = Task { [weak self] in
			guard let self else { return }
			do {
				let launch = try await runtime.launch(
					gameExecutable: executable,
					prefixDirectory: paths.winePrefix,
					gameArguments: (configuration?.gameStartParams ?? [])
						+ launchOptions.playerArguments,
					displayConfiguration: displayConfiguration,
					graphicsDiagnostics: graphicsDiagnosticsEnabled,
					logURL: paths.logFile,
					log: log
				)
				await log.info(
					"Game runtime started; pid=\(launch.processIdentifier); elapsed=\(Self.launchDuration(since: launchRequestedAt))"
				)
				monitorGame(launch: launch, runtime: runtime, sessionID: gameSessionID)
				try await WineWindowReadiness.wait(
					processIdentifier: launch.processIdentifier
				)
				guard activeGameSessionID == gameSessionID, isGameActive else { return }
				phase = .running(processIdentifier: launch.processIdentifier)
				activityMessage = "Running"
				monitorGamePrefix(using: runtime, sessionID: gameSessionID)
				await log.info(
					"Game window became visible; elapsed=\(Self.launchDuration(since: launchRequestedAt))"
				)
			} catch is CancellationError {
				guard activeGameSessionID == gameSessionID else { return }
				activeGameSessionID = nil
				phase = .ready
				activityMessage = isGameUpdateAvailable ? "Update available" : "Ready"
			} catch LauncherError.runtimeWindowTimeout {
				guard activeGameSessionID == gameSessionID else { return }
				activeGameSessionID = nil
				try? await runtime.stop(prefixDirectory: paths.winePrefix)
				show(LauncherError.runtimeWindowTimeout)
			} catch {
				guard activeGameSessionID == gameSessionID else { return }
				activeGameSessionID = nil
				show(error)
			}
		}
	}

	private static func launchDuration(since start: Date, now: Date = Date()) -> String {
		String(format: "%.2fs", max(0, now.timeIntervalSince(start)))
	}

	func stopGame() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.ready)
				return
			}
		#endif
		guard canStopGame, let runtime = WineRuntime.discover() else { return }
		isStoppingGame = true
		activityMessage = "Stopping…"
		launchTask?.cancel()
		Task { [weak self] in
			guard let self else { return }
			defer { isStoppingGame = false }
			do {
				await log.info("Game stop requested")
				try await runtime.stop(prefixDirectory: paths.winePrefix)
			} catch {
				show(error)
			}
		}
	}

	func stopGameForApplicationTermination() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		guard isGameActive, let runtime = WineRuntime.discover() else { return }
		runtime.stopSynchronously(prefixDirectory: paths.winePrefix)
	}

	func refreshRuntime() {
		runtimeName = WineRuntime.discover()?.displayName
	}

	/// Discards the prefix's recorded migration state so the next launch fully
	/// replays Wine initialization, DXMT installation, and registry overrides.
	/// Leaves game files and Wine's own user directories untouched.
	func forcePrefixMigration() {
		guard !isDownloading, !isGameActive else { return }
		do {
			try RuntimeMigrationStore().reset(prefixDirectory: paths.winePrefix)
			activityMessage = "Wine setup will run again on next launch"
			Task { [log] in await log.info("Wine prefix migration state was reset on request") }
		} catch {
			show(error)
		}
	}

	func monitorGame(
		launch: WineLaunch,
		runtime: WineRuntime,
		sessionID: UUID
	) {
		gameMonitorTask?.cancel()
		gameProcessMonitorTask?.cancel()
		let log = log
		let logURL = paths.logFile
		gameProcessMonitorTask = Task { [weak self, log, logURL] in
			let status = await launch.waitUntilExit()
			guard
				let self,
				!Task.isCancelled
			else { return }
			switch Self.directWineProcessExitAction(
				for: status,
				phase: phase,
				hasActiveSession: activeGameSessionID == sessionID
			) {
			case .ignore:
				return
			case .startupFailure:
				activeGameSessionID = nil
				launchTask?.cancel()
				await log.error("Game process exited unexpectedly; status=\(status)")
				show(LauncherError.runtimeExited(status: status, log: logURL))
			case .gameExited:
				await log.info("Game process exited; status=\(status)")
				do {
					try await runtime.stop(prefixDirectory: paths.winePrefix)
				} catch {
					await log.error(
						"Runtime cleanup after game exit failed: \(error.localizedDescription)"
					)
				}
				await finishGameSession(sessionID, log: log)
			}
		}
	}

	func monitorGamePrefix(using runtime: WineRuntime, sessionID: UUID) {
		gameMonitorTask?.cancel()
		let prefixDirectory = paths.winePrefix
		let log = log
		gameMonitorTask = Task { [weak self, log, prefixDirectory] in
			do {
				try await runtime.waitUntilStopped(prefixDirectory: prefixDirectory)
			} catch {
				guard !Task.isCancelled else { return }
				await log.error("Game process monitor failed: \(error.localizedDescription)")
			}
			guard
				let self,
				!Task.isCancelled,
				activeGameSessionID == sessionID
			else { return }
			await finishGameSession(sessionID, log: log)
		}
	}

	func finishGameSession(_ sessionID: UUID, log: LauncherLog) async {
		guard activeGameSessionID == sessionID else { return }
		activeGameSessionID = nil
		launchTask?.cancel()
		phase = .ready
		activityMessage = isGameUpdateAvailable ? "Update available" : "Ready"
		await log.info("Game process stopped")
	}
}
