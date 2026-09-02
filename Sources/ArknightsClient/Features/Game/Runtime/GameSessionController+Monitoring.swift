// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameSessionController {
	func stopGame() {
		guard let sessionID = activeGameSessionID else { return }
		let processIdentifier = lifecycle.activity.gameProcessIdentifier
		let region = activeGameRegion ?? installation.region
		let runtime: any WineRuntimeSessionControlling
		do {
			runtime = try runtimeSessionControllerProvider()
		} catch {
			presentRuntimeFailure(
				error,
				id: sessionID,
				operation: .runtimeStop,
				region: region
			)
			return
		}
		if let processIdentifier {
			lifecycle.activity = .stoppingGame(
				sessionID: sessionID,
				processIdentifier: processIdentifier
			)
		}
		lifecycle.setStatus(.stoppingGame)
		launchTask?.cancel()
		gameMonitorTask?.cancel()
		gameMonitorTask = Task { [weak self] in
			guard let self else { return }
			await log.info("Game stop requested")
			guard activeGameSessionID == sessionID else { return }
			await stopAndFinishGameSession(
				using: runtime,
				sessionID: sessionID,
				processIdentifier: processIdentifier,
				region: region
			)
		}
	}

	func stopGameForApplicationTermination() {
		guard isGameActive else { return }
		if let activeGameSessionID {
			playtimeStatistics.finish(sessionID: activeGameSessionID)
		}
		disableActiveGameMode()
		let runtime: WineRuntime
		do {
			runtime = try discoverRuntime()
		} catch {
			Task { [log] in
				await log.error(
					"Could not stop Wine during app termination: \(error.localizedDescription)"
				)
			}
			return
		}
		runtime.stopSynchronously(
			prefixDirectory: paths.winePrefix(for: activeGameRegion ?? installation.region),
			log: log
		)
	}

	func monitorGame(
		launch: WineLaunch,
		runtime: any WineRuntimeSessionControlling,
		sessionID: UUID
	) {
		gameMonitorTask?.cancel()
		gameProcessMonitorTask?.cancel()
		let logURL = paths.wineLogFile(for: activeGameRegion ?? installation.region)
		gameProcessMonitorTask = Task { [weak self, log, logURL] in
			let exit = await launch.waitUntilExit()
			guard let self, !Task.isCancelled else { return }
			let region = activeGameRegion ?? installation.region
			switch Self.directWineProcessExitAction(
				activity: lifecycle.activity,
				sessionID: sessionID
			) {
			case .ignore:
				return
			case .startupFailure:
				markGameSessionStopping(sessionID, processIdentifier: launch.processIdentifier)
				launchTask?.cancel()
				let since = gameRunningSince
				let diagnostics = await Task.detached(priority: .utility) {
					Self.exitDiagnostics(exit, since: since, logURL: logURL)
				}.value
				guard activeGameSessionID == sessionID else { return }
				await log.error("Game process exited unexpectedly; \(diagnostics)")
				guard activeGameSessionID == sessionID else { return }
				await stopAndFinishGameSession(
					using: runtime,
					sessionID: sessionID,
					processIdentifier: launch.processIdentifier,
					region: region,
					terminalFailure: GameSessionTerminalFailure(
						error: LauncherError.runtimeExited(status: exit.status, log: logURL),
						operation: .runtimeExit,
						blocksGameLaunch: true
					)
				)
			case .gameExited:
				markGameSessionStopping(sessionID, processIdentifier: launch.processIdentifier)
				let since = gameRunningSince
				gameRunningSince = nil
				let diagnostics = await Task.detached(priority: .utility) {
					Self.exitDiagnostics(
						exit,
						since: since,
						logURL: exit.status == 0 && exit.reason == .exit ? nil : logURL
					)
				}.value
				guard activeGameSessionID == sessionID else { return }
				if exit.status == 0, exit.reason == .exit {
					await log.info("Game process exited; \(diagnostics)")
				} else {
					await log.error("Game process exited unexpectedly; \(diagnostics)")
				}
				guard activeGameSessionID == sessionID else { return }
				let failure =
					exit.status == 0 && exit.reason == .exit
					? nil
					: GameSessionTerminalFailure(
						error: LauncherError.runtimeExited(status: exit.status, log: logURL),
						operation: .runtimeExit,
						blocksGameLaunch: false
					)
				await stopAndFinishGameSession(
					using: runtime,
					sessionID: sessionID,
					processIdentifier: launch.processIdentifier,
					region: region,
					terminalFailure: failure
				)
			}
		}
	}

	func monitorGamePrefix(
		using runtime: any WineRuntimeSessionControlling,
		sessionID: UUID
	) {
		gameMonitorTask?.cancel()
		let prefixDirectory = paths.winePrefix(for: activeGameRegion ?? installation.region)
		gameMonitorTask = Task { [weak self, log, prefixDirectory] in
			do {
				try await runtime.waitUntilStopped(prefixDirectory: prefixDirectory)
			} catch {
				guard !Task.isCancelled else { return }
				await log.error("Game process monitor failed: \(error.localizedDescription)")
				guard let self, !Task.isCancelled, activeGameSessionID == sessionID else {
					return
				}
				await stopAndFinishGameSession(
					using: runtime,
					sessionID: sessionID,
					processIdentifier: lifecycle.activity.gameProcessIdentifier,
					region: activeGameRegion ?? installation.region
				)
				return
			}
			guard let self, !Task.isCancelled, activeGameSessionID == sessionID else { return }
			if let gameProcessMonitorTask { await gameProcessMonitorTask.value }
			guard !Task.isCancelled, activeGameSessionID == sessionID else { return }
			finishGameSession(sessionID)
		}
	}

	func stopAndFinishGameSession(
		using runtime: any WineRuntimeSessionControlling,
		sessionID: UUID,
		processIdentifier: Int32?,
		region: GameRegion,
		terminalFailure: GameSessionTerminalFailure? = nil
	) async {
		guard activeGameSessionID == sessionID else { return }
		rememberTerminalFailure(terminalFailure, for: sessionID)
		markGameSessionStopping(sessionID, processIdentifier: processIdentifier)
		do {
			try await runtime.stop(prefixDirectory: paths.winePrefix(for: region))
		} catch {
			guard activeGameSessionID == sessionID else { return }
			await log.error("Runtime cleanup failed: \(error.localizedDescription)")
			guard activeGameSessionID == sessionID else { return }
			presentRuntimeFailure(
				error,
				id: sessionID,
				operation: .runtimeStop,
				region: region
			)
			return
		}
		guard activeGameSessionID == sessionID else { return }
		finishGameSession(sessionID)
	}

	func finishGameSession(_ sessionID: UUID) {
		guard activeGameSessionID == sessionID else { return }
		let terminalFailure = takeTerminalFailure(for: sessionID)
		let sessionRegion = activeGameRegion ?? installation.region
		playtimeStatistics.finish(sessionID: sessionID)
		lifecycle.activity = .idle
		launchTask?.cancel()
		gameMonitorTask?.cancel()
		gameProcessMonitorTask?.cancel()
		disableActiveGameMode()
		activeGameRegion = nil
		lifecycle.setStatus(installation.isGameUpdateAvailable ? .updateAvailable : .ready)
		if let terminalFailure {
			presentRuntimeFailure(
				terminalFailure.error,
				id: sessionID,
				operation: terminalFailure.operation,
				region: sessionRegion,
				blocksGameLaunch: terminalFailure.blocksGameLaunch
			)
		}
		Task { [log] in await log.info("Game process stopped") }
	}

	private func markGameSessionStopping(_ sessionID: UUID, processIdentifier: Int32?) {
		guard activeGameSessionID == sessionID else { return }
		if let processIdentifier {
			lifecycle.activity = .stoppingGame(
				sessionID: sessionID,
				processIdentifier: processIdentifier
			)
		}
		lifecycle.setStatus(.stoppingGame)
	}

	func disableActiveGameMode() {
		guard activeGameModeEnabled else { return }
		activeGameModeEnabled = false
		GamePolicyControl.setGameMode(on: false, log: log)
	}
}
