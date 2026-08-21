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
		guard state.activity == .idle else { return }
		let executable = installDirectory.appending(
			path: configuration?.executableName ?? "Arknights.exe")
		guard FileManager.default.fileExists(atPath: executable.path) else {
			show(LauncherError.gameNotInstalled(executable))
			return
		}
		let runtime: WineRuntime
		do {
			runtime = try discoverRuntime()
		} catch {
			refreshRuntime()
			show(error)
			return
		}
		guard intelTranslationState.allowsWine else {
			show(intelTranslationLaunchError)
			return
		}

		let hasPendingMigration = runtime.hasPendingMigration(prefixDirectory: paths.winePrefix)
		let gameSessionID = UUID()
		if hasPendingMigration {
			state.activity = .preparingGame(sessionID: gameSessionID)
			setStatus(.preparingWine)
		} else {
			state.activity = .launchingGame(sessionID: gameSessionID, processIdentifier: nil)
			setStatus(.startingGame)
		}
		Task { [log] in
			await log.debug("Pending Wine prefix migration check: \(hasPendingMigration)")
		}
		let launchRequestedAt = Date.now
		let requestedLaunchOptions = launchOptions
		let displayConfiguration = WineDisplayConfiguration.current(
			highResolutionEnabled: requestedLaunchOptions.usesHighResolutionMode,
			forceDisabled: preferences.forceDisableRetina()
		)
		Task { [log] in
			await log.info(
				"Game launch requested; synchronization=\(requestedLaunchOptions.synchronizationMode.displayName)"
			)
		}
		launchTask?.cancel()
		launchTask = Task { [weak self] in
			guard let self else { return }
			do {
				let launch = try await runtime.launch(
					gameExecutable: executable,
					prefixDirectory: paths.winePrefix,
					gameArguments: ["-logFile", AppPaths.windowsUnityLogPath]
						+ (configuration?.gameStartParams ?? [])
						+ requestedLaunchOptions.playerArguments,
					displayConfiguration: displayConfiguration,
					graphicsDiagnostics: graphicsDiagnosticsEnabled,
					metalPerformanceHUDEnabled: requestedLaunchOptions.usesMetalPerformanceHUD,
					synchronizationMode: requestedLaunchOptions.synchronizationMode,
					gameIconURL: hasCustomGameIcon ? paths.customGameIcon : nil,
					logURL: paths.logFile,
					log: log
				)
				await log.info(
					"Game runtime started; pid=\(launch.processIdentifier); elapsed=\(Self.launchDuration(since: launchRequestedAt))"
				)
				guard activeGameSessionID == gameSessionID else { return }
				if requestedLaunchOptions.usesGameMode {
					GamePolicyControl.setGameMode(on: true, log: log)
				}
				state.activity = .launchingGame(
					sessionID: gameSessionID,
					processIdentifier: launch.processIdentifier
				)
				setStatus(.startingGame)
				monitorGame(launch: launch, runtime: runtime, sessionID: gameSessionID)
				try await WineWindowReadiness.wait(
					processIdentifier: launch.processIdentifier
				)
				guard activeGameSessionID == gameSessionID, isGameActive else { return }
				state.activity = .runningGame(
					sessionID: gameSessionID,
					processIdentifier: launch.processIdentifier
				)
				setStatus(.running)
				gameRunningSince = .now
				monitorGamePrefix(using: runtime, sessionID: gameSessionID)
				await log.info(
					"Game window became visible; elapsed=\(Self.launchDuration(since: launchRequestedAt))"
				)
			} catch is CancellationError {
				guard activeGameSessionID == gameSessionID else { return }
				state.activity = .idle
				setStatus(isGameUpdateAvailable ? .updateAvailable : .ready)
			} catch LauncherError.runtimeWindowTimeout {
				guard activeGameSessionID == gameSessionID else { return }
				state.activity = .idle
				if requestedLaunchOptions.usesGameMode {
					GamePolicyControl.setGameMode(on: false, log: log)
				}
				do {
					try await runtime.stop(prefixDirectory: paths.winePrefix)
				} catch {
					await log.error(
						"Failed to stop Wine after window readiness timed out: \(error.localizedDescription)"
					)
				}
				show(LauncherError.runtimeWindowTimeout)
			} catch {
				guard activeGameSessionID == gameSessionID else { return }
				state.activity = .idle
				if requestedLaunchOptions.usesGameMode {
					GamePolicyControl.setGameMode(on: false, log: log)
				}
				if RosettaAvailability.isBadCPUType(error) {
					intelTranslationState = .unavailable
					show(LauncherError.intelTranslationUnavailable)
				} else {
					show(error)
				}
			}
		}
	}

	func stopGame() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.ready)
				return
			}
		#endif
		guard case .runningGame(let sessionID, let processIdentifier) = state.activity else {
			return
		}
		let runtime: WineRuntime
		do {
			runtime = try discoverRuntime()
		} catch {
			show(error)
			return
		}
		state.activity = .stoppingGame(
			sessionID: sessionID,
			processIdentifier: processIdentifier
		)
		setStatus(.stoppingGame)
		launchTask?.cancel()
		Task { [weak self] in
			guard let self else { return }
			do {
				await log.info("Game stop requested")
				try await runtime.stop(prefixDirectory: paths.winePrefix)
			} catch {
				if case .stoppingGame(let activeSessionID, _) = state.activity,
					activeSessionID == sessionID
				{
					state.activity = .runningGame(
						sessionID: sessionID,
						processIdentifier: processIdentifier
					)
				}
				show(error)
			}
		}
	}

	func stopGameForApplicationTermination() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		guard isGameActive else { return }
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
		if launchOptions.usesGameMode { GamePolicyControl.setGameMode(on: false, log: log) }
		runtime.stopSynchronously(prefixDirectory: paths.winePrefix, log: log)
	}

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

	private func discoverRuntime() throws -> WineRuntime {
		try WineRuntime.discover(compatibilityManager: gameCompatibilityManager)
	}

	/// Discards the prefix's recorded migration state so the next launch fully
	/// replays Wine initialization, DXMT installation, and registry overrides.
	/// Leaves game files and Wine's own user directories untouched.
	func forcePrefixMigration() {
		guard state.activity == .idle else { return }
		do {
			try RuntimeMigrationStore().reset(prefixDirectory: paths.winePrefix)
			setStatus(.custom("Wine setup will run again on next launch"))
			Task { [log] in await log.info("Wine prefix migration state was reset on request") }
		} catch {
			show(error)
		}
	}

	/// Unlike `forcePrefixMigration`, this removes the whole prefix, including Wine's own
	/// user directories — the embedded browser's saved Yostar, Google, Apple, and Facebook
	/// login sessions are gone too. The migration state that method resets lives inside the
	/// prefix, so this also makes the next launch fully replay Wine setup.
	func deleteWinePrefix() {
		guard state.activity == .idle else { return }
		let prefixDirectory = paths.winePrefix
		guard FileManager.default.fileExists(atPath: prefixDirectory.path) else { return }
		state.activity = .maintaining(.deletingWinePrefix)
		setStatus(.custom("Deleting Wine prefix…"))
		Task { [weak self] in
			guard let self else { return }
			do {
				try await Task.detached(priority: .userInitiated) {
					try FileManager.default.removeItem(at: prefixDirectory)
				}.value
				state.activity = .idle
				setStatus(.custom("Wine prefix deleted; setup will run again on next launch"))
				await log.info("Wine prefix deleted on request")
			} catch {
				state.activity = .idle
				show(error)
			}
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
			let exit = await launch.waitUntilExit()
			guard
				let self,
				!Task.isCancelled
			else { return }
			switch Self.directWineProcessExitAction(
				activity: state.activity,
				sessionID: sessionID
			) {
			case .ignore:
				return
			case .startupFailure:
				state.activity = .idle
				launchTask?.cancel()
				let since = gameRunningSince
				let diagnostics = await Task.detached(priority: .utility) {
					Self.exitDiagnostics(exit, since: since, logURL: logURL)
				}.value
				await log.error(
					"Game process exited unexpectedly; \(diagnostics)"
				)
				show(LauncherError.runtimeExited(status: exit.status, log: logURL))
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
		state.activity = .idle
		launchTask?.cancel()
		if launchOptions.usesGameMode { GamePolicyControl.setGameMode(on: false, log: log) }
		setStatus(isGameUpdateAvailable ? .updateAvailable : .ready)
		await log.info("Game process stopped")
	}
}
