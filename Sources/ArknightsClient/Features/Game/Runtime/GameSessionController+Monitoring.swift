// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameSessionController {
	func stopGame() {
		guard let sessionID = activeGameSessionID, canStopGame else { return }
		let processIdentifier = lifecycle.activity.gameProcessIdentifier
		let region = session?.region ?? installation.region
		guard let processIdentifier else {
			// Wine is still being prepared or spawned; the launch task owns cleanup so a game
			// process that spawns concurrently is still stopped afterwards.
			session?.spawnGate.denyFurtherSpawns()
			updateSessionActivity(.stoppingGame(sessionID: sessionID, processIdentifier: nil))
			lifecycle.setStatus(.stoppingGame)
			log.info("Game stop requested during launch")
			session?.launchTask?.cancel()
			return
		}
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
		beginStopGame(
			using: runtime,
			sessionID: sessionID,
			processIdentifier: processIdentifier,
			region: region
		)
	}

	func retryFailedRuntimeStop(sessionID: UUID, region: GameRegion) {
		guard activeGameSessionID == sessionID,
			session?.region == region,
			session?.isRuntimeStopInFlight != true,
			lifecycle.activity.activeGameSessionID == sessionID
		else { return }
		let processIdentifier = lifecycle.activity.gameProcessIdentifier
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
		beginStopGame(
			using: runtime,
			sessionID: sessionID,
			processIdentifier: processIdentifier,
			region: region
		)
	}

	private func beginStopGame(
		using runtime: any WineRuntimeSessionControlling,
		sessionID: UUID,
		processIdentifier: Int32?,
		region: GameRegion
	) {
		session?.spawnGate.denyFurtherSpawns()
		updateSessionActivity(
			.stoppingGame(
				sessionID: sessionID,
				processIdentifier: processIdentifier
			))
		lifecycle.setStatus(.stoppingGame)
		session?.launchTask?.cancel()
		session?.monitorTask?.cancel()
		session?.monitorTask = Task { [weak self] in
			guard let self else { return }
			log.info("Game stop requested")
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
		guard isGameActive, !applicationTerminationRequested else { return }
		prepareForApplicationTermination()
		if let activeGameSessionID {
			playtimeStatistics.finish(sessionID: activeGameSessionID)
		}
		disableActiveGameMode()
		let runtime: WineRuntime
		do {
			runtime = try discoverRuntime()
		} catch {
			log.error(
				"Could not stop Wine during app termination: \(launcherDiagnosticDescription(for: error))"
			)
			return
		}
		runtime.stopSynchronously(
			prefixDirectory: paths.winePrefix(for: session?.region ?? installation.region),
			log: log
		)
	}

	func prepareForApplicationTermination() {
		applicationTerminationRequested = true
		session?.spawnGate.denyFurtherSpawns()
		session?.cancelTasks()
		if let sessionID = activeGameSessionID {
			updateSessionActivity(
				.stoppingGame(
					sessionID: sessionID,
					processIdentifier: lifecycle.activity.gameProcessIdentifier
				))
			lifecycle.setStatus(.stoppingGame)
		}
	}

	func monitorGame(
		launch: WineLaunch,
		runtime: any WineRuntimeSessionControlling,
		sessionID: UUID
	) {
		session?.monitorTask?.cancel()
		session?.processMonitorTask?.cancel()
		let logURL = paths.runtimeLogFile(for: session?.region ?? installation.region)
		session?.processMonitorTask = Task { [weak self, log, logURL] in
			let exit = await launch.waitUntilExit()
			guard let self, !Task.isCancelled else { return }
			let region = session?.region ?? installation.region
			switch Self.directWineProcessExitAction(
				activity: lifecycle.activity,
				sessionID: sessionID
			) {
			case .ignore:
				return
			case .startupFailure:
				markGameSessionStopping(sessionID, processIdentifier: launch.processIdentifier)
				session?.launchTask?.cancel()
				let since = gameRunningSince
				let diagnostics = await Task.detached(priority: .utility) {
					Self.exitDiagnostics(exit, since: since, logURL: logURL)
				}.value
				guard activeGameSessionID == sessionID else { return }
				log.error("Game process exited unexpectedly; \(diagnostics)")
				await stopAndFinishGameSession(
					using: runtime,
					sessionID: sessionID,
					processIdentifier: launch.processIdentifier,
					region: region,
					terminalFailure: GameSessionTerminalFailure(
						error: GameRuntimeError.runtimeExited(status: exit.status, log: logURL),
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
					log.info("Game process exited; \(diagnostics)")
				} else {
					log.error("Game process exited unexpectedly; \(diagnostics)")
				}
				guard activeGameSessionID == sessionID else { return }
				let failure =
					exit.status == 0 && exit.reason == .exit
					? nil
					: GameSessionTerminalFailure(
						error: GameRuntimeError.runtimeExited(status: exit.status, log: logURL),
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
		session?.monitorTask?.cancel()
		let prefixDirectory = paths.winePrefix(for: session?.region ?? installation.region)
		session?.monitorTask = Task { [weak self, log, prefixDirectory] in
			do {
				try await runtime.waitUntilStopped(prefixDirectory: prefixDirectory)
			} catch {
				guard !Task.isCancelled else { return }
				log.error(
					"Game process monitor failed: \(launcherDiagnosticDescription(for: error))")
				guard let self, !Task.isCancelled, activeGameSessionID == sessionID else {
					return
				}
				await stopAndFinishGameSession(
					using: runtime,
					sessionID: sessionID,
					processIdentifier: lifecycle.activity.gameProcessIdentifier,
					region: session?.region ?? installation.region
				)
				return
			}
			guard let self, !Task.isCancelled, activeGameSessionID == sessionID else { return }
			if let processMonitorTask = session?.processMonitorTask {
				await processMonitorTask.value
			}
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
		guard session?.isRuntimeStopInFlight != true else { return }
		session?.isRuntimeStopInFlight = true
		defer {
			if session?.id == sessionID {
				session?.isRuntimeStopInFlight = false
			}
		}
		let spawnGate = session?.spawnGate
		spawnGate?.denyFurtherSpawns()
		rememberTerminalFailure(terminalFailure, for: sessionID)
		markGameSessionStopping(sessionID, processIdentifier: processIdentifier)
		do {
			let prefixDirectory = paths.winePrefix(for: region)
			// Cancelling the owning task must not skip prefix shutdown; the wineserver wait runs inside stop.
			// An unstructured task does not inherit cancellation, and `withTaskCancellationShield` needs macOS 27.
			try await Task {
				try await runtime.stop(prefixDirectory: prefixDirectory, spawnGate: spawnGate)
			}.value
		} catch {
			guard activeGameSessionID == sessionID else { return }
			log.error("Runtime cleanup failed: \(launcherDiagnosticDescription(for: error))")
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
		let sessionRegion = session?.region ?? installation.region
		playtimeStatistics.finish(sessionID: sessionID)
		if let lease = session?.lease {
			lifecycle.end(lease)
		}
		disableActiveGameMode()
		session?.cancelTasks()
		session = nil
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
		log.info("Game process stopped")
	}

	private func markGameSessionStopping(_ sessionID: UUID, processIdentifier: Int32?) {
		guard activeGameSessionID == sessionID else { return }
		updateSessionActivity(
			.stoppingGame(
				sessionID: sessionID,
				processIdentifier: processIdentifier ?? lifecycle.activity.gameProcessIdentifier
			))
		lifecycle.setStatus(.stoppingGame)
	}

	/// Changes the session activity through the session lease. Without a lease it changes nothing.
	func updateSessionActivity(_ activity: LauncherActivity, lease: ActivityLease? = nil) {
		guard let lease = lease ?? session?.lease else { return }
		lifecycle.update(lease, to: activity)
	}

	func disableActiveGameMode() {
		guard session?.usesGameMode == true else { return }
		session?.usesGameMode = false
		GamePolicyControl.setGameMode(on: false, log: log)
	}
}
