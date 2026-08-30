// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameSessionController {
	func stopGame() {
		guard case .runningGame(let sessionID, let processIdentifier) = lifecycle.activity else {
			return
		}
		let runtime: WineRuntime
		do {
			runtime = try discoverRuntime()
		} catch {
			presentRuntimeFailure(
				error,
				id: sessionID,
				operation: .runtimeStop,
				region: installation.region
			)
			return
		}
		lifecycle.activity = .stoppingGame(
			sessionID: sessionID,
			processIdentifier: processIdentifier
		)
		lifecycle.setStatus(.stoppingGame)
		launchTask?.cancel()
		Task { [weak self] in
			guard let self else { return }
			do {
				await log.info("Game stop requested")
				try await runtime.stop(prefixDirectory: paths.winePrefix)
			} catch {
				if case .stoppingGame(let activeSessionID, _) = lifecycle.activity,
					activeSessionID == sessionID
				{
					lifecycle.activity = .runningGame(
						sessionID: sessionID,
						processIdentifier: processIdentifier
					)
				}
				presentRuntimeFailure(
					error,
					id: sessionID,
					operation: .runtimeStop,
					region: installation.region
				)
			}
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
		runtime.stopSynchronously(prefixDirectory: paths.winePrefix, log: log)
	}

	func monitorGame(launch: WineLaunch, runtime: WineRuntime, sessionID: UUID) {
		gameMonitorTask?.cancel()
		gameProcessMonitorTask?.cancel()
		let logURL = paths.logFile
		gameProcessMonitorTask = Task { [weak self, log, logURL] in
			let exit = await launch.waitUntilExit()
			guard let self, !Task.isCancelled else { return }
			switch Self.directWineProcessExitAction(
				activity: lifecycle.activity,
				sessionID: sessionID
			) {
			case .ignore:
				return
			case .startupFailure:
				lifecycle.activity = .idle
				launchTask?.cancel()
				disableActiveGameMode()
				let since = gameRunningSince
				let diagnostics = await Task.detached(priority: .utility) {
					Self.exitDiagnostics(exit, since: since, logURL: logURL)
				}.value
				await log.error("Game process exited unexpectedly; \(diagnostics)")
				presentRuntimeFailure(
					LauncherError.runtimeExited(status: exit.status, log: logURL),
					id: sessionID,
					operation: .runtimeExit,
					region: installation.region,
					blocksGameLaunch: true
				)
			case .gameExited:
				let since = gameRunningSince
				gameRunningSince = nil
				let diagnostics = await Task.detached(priority: .utility) {
					Self.exitDiagnostics(
						exit,
						since: since,
						logURL: exit.status == 0 && exit.reason == .exit ? nil : logURL
					)
				}.value
				if exit.status == 0, exit.reason == .exit {
					await log.info("Game process exited; \(diagnostics)")
				} else {
					await log.error("Game process exited unexpectedly; \(diagnostics)")
				}
				do {
					try await runtime.stop(prefixDirectory: paths.winePrefix)
				} catch {
					await log.error(
						"Runtime cleanup after game exit failed: \(error.localizedDescription)"
					)
				}
				await finishGameSession(sessionID)
				if exit.status != 0 || exit.reason != .exit {
					presentRuntimeFailure(
						LauncherError.runtimeExited(status: exit.status, log: logURL),
						id: sessionID,
						operation: .runtimeExit,
						region: installation.region
					)
				}
			}
		}
	}

	func monitorGamePrefix(using runtime: WineRuntime, sessionID: UUID) {
		gameMonitorTask?.cancel()
		let prefixDirectory = paths.winePrefix
		gameMonitorTask = Task { [weak self, log, prefixDirectory] in
			do {
				try await runtime.waitUntilStopped(prefixDirectory: prefixDirectory)
			} catch {
				guard !Task.isCancelled else { return }
				await log.error("Game process monitor failed: \(error.localizedDescription)")
			}
			guard let self, !Task.isCancelled, activeGameSessionID == sessionID else { return }
			await finishGameSession(sessionID)
		}
	}

	func finishGameSession(_ sessionID: UUID) async {
		guard activeGameSessionID == sessionID else { return }
		playtimeStatistics.finish(sessionID: sessionID)
		lifecycle.activity = .idle
		launchTask?.cancel()
		disableActiveGameMode()
		lifecycle.setStatus(installation.isGameUpdateAvailable ? .updateAvailable : .ready)
		await log.info("Game process stopped")
	}

	func disableActiveGameMode() {
		guard activeGameModeEnabled else { return }
		activeGameModeEnabled = false
		GamePolicyControl.setGameMode(on: false, log: log)
	}
}
