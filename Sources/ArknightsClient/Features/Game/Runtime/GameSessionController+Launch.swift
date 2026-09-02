// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameSessionController {
	func launch() {
		guard lifecycle.activity == .idle else { return }
		let launchID = UUID()
		let requestedRegion = installation.region
		let isChina = requestedRegion.isChinaClient
		let executable = installation.installDirectory.appending(
			path: installation.configuration?.executableName ?? "Arknights.exe"
		)
		guard FileManager.default.fileExists(atPath: executable.path) else {
			presentRuntimeFailure(
				LauncherError.gameNotInstalled(executable),
				id: launchID,
				operation: .launch,
				region: requestedRegion
			)
			return
		}
		let runtime: WineRuntime
		do {
			runtime = try discoverRuntime()
		} catch {
			refreshRuntime()
			presentRuntimeFailure(
				error,
				id: launchID,
				operation: .runtimeDiscovery,
				region: requestedRegion
			)
			return
		}
		guard lifecycle.intelTranslationState.allowsWine else {
			presentRuntimeFailure(
				intelTranslation.launchError,
				id: launchID,
				operation: .launch,
				region: requestedRegion
			)
			return
		}

		let prefixDirectory = paths.winePrefix(for: requestedRegion)
		let hasPendingMigration: Bool
		do {
			hasPendingMigration = try runtime.hasPendingMigration(prefixDirectory: prefixDirectory)
		} catch {
			presentRuntimeFailure(
				error,
				id: launchID,
				operation: .runtimeDiscovery,
				region: requestedRegion
			)
			return
		}
		let gameSessionID = launchID
		activeGameRegion = requestedRegion
		resetTerminalFailure()
		if hasPendingMigration {
			lifecycle.activity = .preparingGame(sessionID: gameSessionID)
			lifecycle.setStatus(.preparingWine)
		} else {
			lifecycle.activity = .launchingGame(
				sessionID: gameSessionID,
				processIdentifier: nil
			)
			lifecycle.setStatus(.startingGame)
		}
		Task { [log] in
			await log.debug("Pending Wine prefix migration check: \(hasPendingMigration)")
		}
		let launchRequestedAt = Date.now
		let requestedLaunchOptions = settings.launchOptions
		var runtimeEnvironment = [
			"ARKNIGHTS_RUNTIME_CN_COMPAT": isChina ? "1" : "0"
		]
		if settings.canaryFeaturesEnabled {
			runtimeEnvironment["ARKNIGHTS_RUNTIME_AUDIO_FOLLOW_DEFAULT_OUTPUT"] =
				settings.followsDefaultAudioOutput ? "1" : "0"
			runtimeEnvironment["ARKNIGHTS_RUNTIME_DXMT_MAX_FRAME_LATENCY"] =
				String(settings.maximumFrameLatency)
		}
		activeGameModeEnabled = requestedLaunchOptions.usesGameMode
		let displayConfiguration = WineDisplayConfiguration.current(
			highResolutionEnabled: requestedLaunchOptions.usesHighResolutionMode,
			forceDisabled: preferences.forceDisableRetina()
		)
		Task { [log] in
			await log.info(
				Self.launchDiagnostics(
					sessionID: gameSessionID,
					region: requestedRegion,
					options: requestedLaunchOptions,
					graphicsDiagnosticsEnabled: graphicsDiagnosticsEnabled
				)
			)
		}
		launchTask?.cancel()
		launchTask = Task { [weak self] in
			guard let self else { return }
			do {
				let launch = try await runtime.launch(
					gameExecutable: executable,
					prefixDirectory: prefixDirectory,
					gameArguments: ["-logFile", AppPaths.windowsUnityLogPath]
						+ (installation.configuration?.gameStartParams ?? [])
						+ requestedLaunchOptions.playerArguments,
					displayConfiguration: displayConfiguration,
					graphicsDiagnostics: graphicsDiagnosticsEnabled,
					metalPerformanceHUDEnabled: requestedLaunchOptions.usesMetalPerformanceHUD,
					synchronizationMode: requestedLaunchOptions.synchronizationMode,
					runtimeEnvironmentOverrides: runtimeEnvironment,
					gameIconURL: customGameIconURL(),
					logURL: paths.wineLogFile(for: requestedRegion),
					log: log
				)
				await log.info(
					"Game runtime started; session=\(gameSessionID.uuidString); pid=\(launch.processIdentifier); elapsed=\(Self.launchDuration(since: launchRequestedAt))"
				)
				guard activeGameSessionID == gameSessionID else { return }
				if requestedLaunchOptions.usesGameMode {
					GamePolicyControl.setGameMode(on: true, log: log)
				}
				lifecycle.activity = .launchingGame(
					sessionID: gameSessionID,
					processIdentifier: launch.processIdentifier
				)
				lifecycle.setStatus(.startingGame)
				monitorGame(launch: launch, runtime: runtime, sessionID: gameSessionID)
				try await WineWindowReadiness.wait(processIdentifier: launch.processIdentifier)
				guard activeGameSessionID == gameSessionID, isGameActive else { return }
				lifecycle.activity = .runningGame(
					sessionID: gameSessionID,
					processIdentifier: launch.processIdentifier
				)
				lifecycle.setStatus(.running)
				gameRunningSince = .now
				playtimeStatistics.start(
					sessionID: gameSessionID,
					region: requestedRegion
				)
				monitorGamePrefix(using: runtime, sessionID: gameSessionID)
				await log.info(
					"Game window became visible; session=\(gameSessionID.uuidString); elapsed=\(Self.launchDuration(since: launchRequestedAt))"
				)
			} catch is CancellationError {
				guard activeGameSessionID == gameSessionID else { return }
				if case .stoppingGame(let sessionID, _) = lifecycle.activity,
					sessionID == gameSessionID
				{
					return
				}
				await stopAndFinishGameSession(
					using: runtime,
					sessionID: gameSessionID,
					processIdentifier: lifecycle.activity.gameProcessIdentifier,
					region: requestedRegion
				)
			} catch LauncherError.runtimeWindowTimeout {
				await handleWindowTimeout(
					runtime: runtime,
					sessionID: gameSessionID,
					region: requestedRegion
				)
			} catch {
				guard activeGameSessionID == gameSessionID else { return }
				let launchError: any Error
				if RosettaAvailability.isBadCPUType(error) {
					lifecycle.intelTranslationState = .unavailable
					launchError = LauncherError.intelTranslationUnavailable
				} else {
					launchError = error
				}
				await stopAndFinishGameSession(
					using: runtime,
					sessionID: gameSessionID,
					processIdentifier: lifecycle.activity.gameProcessIdentifier,
					region: requestedRegion,
					terminalFailure: GameSessionTerminalFailure(
						error: launchError,
						operation: .launch,
						blocksGameLaunch: true
					)
				)
			}
		}
	}

	func handleWindowTimeout(
		runtime: WineRuntime,
		sessionID: UUID,
		region: GameRegion
	) async {
		guard activeGameSessionID == sessionID else { return }
		await stopAndFinishGameSession(
			using: runtime,
			sessionID: sessionID,
			processIdentifier: lifecycle.activity.gameProcessIdentifier,
			region: region,
			terminalFailure: GameSessionTerminalFailure(
				error: LauncherError.runtimeWindowTimeout,
				operation: .launch,
				blocksGameLaunch: true
			)
		)
	}
}
