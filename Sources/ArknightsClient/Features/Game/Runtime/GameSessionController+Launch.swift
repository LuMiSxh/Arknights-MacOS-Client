// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameSessionController {
	func launch() {
		guard lifecycle.activity == .idle else { return }
		let launchID = UUID()
		let requestedRegion = installation.region
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

		let hasPendingMigration = runtime.hasPendingMigration(prefixDirectory: paths.winePrefix)
		let gameSessionID = launchID
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
					prefixDirectory: paths.winePrefix,
					gameArguments: ["-logFile", AppPaths.windowsUnityLogPath]
						+ (installation.configuration?.gameStartParams ?? [])
						+ requestedLaunchOptions.playerArguments,
					displayConfiguration: displayConfiguration,
					graphicsDiagnostics: graphicsDiagnosticsEnabled,
					metalPerformanceHUDEnabled: requestedLaunchOptions.usesMetalPerformanceHUD,
					synchronizationMode: requestedLaunchOptions.synchronizationMode,
					gameIconURL: customGameIconURL(),
					logURL: paths.logFile,
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
				lifecycle.activity = .idle
				disableActiveGameMode()
				lifecycle.setStatus(
					installation.isGameUpdateAvailable ? .updateAvailable : .ready)
			} catch LauncherError.runtimeWindowTimeout {
				await handleWindowTimeout(runtime: runtime, sessionID: gameSessionID)
			} catch {
				guard activeGameSessionID == gameSessionID else { return }
				lifecycle.activity = .idle
				disableActiveGameMode()
				if RosettaAvailability.isBadCPUType(error) {
					lifecycle.intelTranslationState = .unavailable
					presentRuntimeFailure(
						LauncherError.intelTranslationUnavailable,
						id: gameSessionID,
						operation: .launch,
						region: requestedRegion
					)
				} else {
					presentRuntimeFailure(
						error,
						id: gameSessionID,
						operation: .launch,
						region: requestedRegion
					)
				}
			}
		}
	}

	private func handleWindowTimeout(runtime: WineRuntime, sessionID: UUID) async {
		guard activeGameSessionID == sessionID else { return }
		lifecycle.activity = .idle
		disableActiveGameMode()
		do {
			try await runtime.stop(prefixDirectory: paths.winePrefix)
		} catch {
			await log.error(
				"Failed to stop Wine after window readiness timed out: \(error.localizedDescription)"
			)
		}
		presentRuntimeFailure(
			LauncherError.runtimeWindowTimeout,
			id: sessionID,
			operation: .launch,
			region: installation.region
		)
	}
}
