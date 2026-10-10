// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Everything captured when the user asks to play, before the first suspension.
struct LaunchRequest {
	let id: UUID
	let region: GameRegion
	let executable: URL
	let prefixDirectory: URL
	let options: GameLaunchOptions
	let usesHardwareCursor: Bool
	let forceDisableRetina: Bool
	let requestedAt: Date
}

/// Result of the file-system and runtime checks that run off the main actor.
struct LaunchPreflight: Sendable {
	let executableExists: Bool
	/// Nil when the executable is missing, so the runtime was never discovered.
	let runtime: Result<WineRuntime, any Error>?
	/// Nil when no runtime was available to ask.
	let pendingMigration: Result<Bool, any Error>?
}

/// A launch that owns its lease and session. Every later step revalidates `request.id`.
struct LaunchContext {
	let request: LaunchRequest
	let lease: ActivityLease
	let runtime: WineRuntime
}

/// Environment and arguments for the runtime, resolved once capabilities are known.
struct PreparedLaunch {
	let displayConfiguration: WineDisplayConfiguration
	let environment: [String: String]
}

extension GameSessionController {
	@concurrent
	static func preflight(
		executable: URL,
		prefixDirectory: URL,
		compatibilityManager: GameCompatibilityManager
	) async -> LaunchPreflight {
		guard FileManager.default.fileExists(atPath: executable.path) else {
			return LaunchPreflight(executableExists: false, runtime: nil, pendingMigration: nil)
		}
		let runtime = Result {
			try WineRuntime.discover(compatibilityManager: compatibilityManager)
		}
		guard case .success(let discovered) = runtime else {
			return LaunchPreflight(executableExists: true, runtime: runtime, pendingMigration: nil)
		}
		let migration = Result {
			try discovered.hasPendingMigration(prefixDirectory: prefixDirectory)
		}
		return LaunchPreflight(
			executableExists: true, runtime: runtime, pendingMigration: migration)
	}

	/// Whether `id` still owns the not-yet-leased part of a launch.
	private func ownsPendingLaunch(_ id: UUID) -> Bool {
		pendingLaunchID == id && lifecycle.activity == .idle && !applicationTerminationRequested
	}

	/// Runs the preflight, then claims the lease. Only one launch may be pending at a time.
	func startLaunch(_ request: LaunchRequest) async {
		defer { if pendingLaunchID == request.id { pendingLaunchID = nil } }
		let preflight = await Self.preflight(
			executable: request.executable,
			prefixDirectory: request.prefixDirectory,
			compatibilityManager: gameCompatibilityManager
		)
		guard ownsPendingLaunch(request.id) else { return }
		guard let context = beginLease(request, preflight: preflight) else { return }
		session?.launchTask = Task { [weak self] in
			await self?.runLaunch(context)
		}
	}

	/// Maps the preflight outcome to a failure or to a lease and session. No suspension happens
	/// here, so the idle check and the lease claim are atomic.
	private func beginLease(_ request: LaunchRequest, preflight: LaunchPreflight) -> LaunchContext?
	{
		guard preflight.executableExists else {
			presentLaunchFailure(
				LauncherError.gameNotInstalled(request.executable), request: request)
			return nil
		}
		let runtime: WineRuntime
		switch preflight.runtime {
		case .success(let discovered)?:
			runtime = discovered
		case .failure(let error)?:
			runtimeName = nil
			log.error("Runtime discovery failed: \(error.localizedDescription)")
			presentLaunchFailure(error, operation: .runtimeDiscovery, request: request)
			return nil
		case nil:
			return nil
		}
		guard lifecycle.intelTranslationState.allowsWine else {
			presentLaunchFailure(intelTranslation.launchError, request: request)
			return nil
		}
		let hasPendingMigration: Bool
		switch preflight.pendingMigration {
		case .success(let pending)?:
			hasPendingMigration = pending
		case .failure(let error)?:
			presentLaunchFailure(error, operation: .runtimeDiscovery, request: request)
			return nil
		case nil:
			return nil
		}
		let initialActivity: LauncherActivity =
			hasPendingMigration
			? .preparingGame(sessionID: request.id)
			: .launchingGame(sessionID: request.id, processIdentifier: nil)
		guard let lease = lifecycle.begin(initialActivity) else { return nil }
		lifecycle.setStatus(hasPendingMigration ? .preparingWine : .startingGame)
		log.debug("Pending Wine prefix migration check: \(hasPendingMigration)")
		log.info(
			Self.launchDiagnostics(
				sessionID: request.id,
				region: request.region,
				options: request.options,
				graphicsDiagnosticsEnabled: graphicsDiagnosticsEnabled
			)
		)
		session = ActiveGameSession(
			id: request.id,
			lease: lease,
			region: request.region,
			spawnGate: WineProcessSpawnGate(),
			usesGameMode: request.options.usesGameMode
		)
		return LaunchContext(request: request, lease: lease, runtime: runtime)
	}

	private func presentLaunchFailure(
		_ error: any Error,
		operation: SupportOperation = .launch,
		request: LaunchRequest
	) {
		presentRuntimeFailure(
			error,
			id: request.id,
			operation: operation,
			region: request.region
		)
	}

	/// Runs the owned launch steps and maps their failure to the matching session cleanup.
	private func runLaunch(_ context: LaunchContext) async {
		let id = context.request.id
		do {
			guard let prepared = try await prepareRuntime(context) else { return }
			guard let launch = try await spawn(context, prepared: prepared) else { return }
			try await monitor(context, launch: launch)
		} catch is CancellationError {
			guard activeGameSessionID == id, !applicationTerminationRequested else { return }
			// Stop owns cleanup once the game process is known.
			if case .stoppingGame(let sessionID, .some) = lifecycle.activity, sessionID == id {
				return
			}
			await stopAfterCancelledLaunch(
				runtime: context.runtime,
				sessionID: id,
				processIdentifier: lifecycle.activity.gameProcessIdentifier,
				region: context.request.region
			)
		} catch LauncherError.runtimeWindowTimeout {
			guard !applicationTerminationRequested else { return }
			await handleWindowTimeout(
				runtime: context.runtime,
				sessionID: id,
				region: context.request.region
			)
		} catch {
			guard activeGameSessionID == id, !applicationTerminationRequested else { return }
			let launchError: any Error
			if RosettaAvailability.isBadCPUType(error) {
				lifecycle.intelTranslationState = .unavailable
				launchError = LauncherError.intelTranslationUnavailable
			} else {
				launchError = error
			}
			await stopAndFinishGameSession(
				using: context.runtime,
				sessionID: id,
				processIdentifier: lifecycle.activity.gameProcessIdentifier,
				region: context.request.region,
				terminalFailure: GameSessionTerminalFailure(
					error: launchError,
					operation: .launch,
					blocksGameLaunch: true
				)
			)
		}
	}

	/// Returns nil when the session no longer owns the launch.
	private func prepareRuntime(_ context: LaunchContext) async throws -> PreparedLaunch? {
		let request = context.request
		let discovery = await context.runtime.discoverCapabilities()
		try Task.checkCancellation()
		guard activeGameSessionID == request.id else { return nil }
		if let diagnostic = discovery.diagnostic {
			log.info("Runtime capability fallback: \(diagnostic)")
		}
		let displayConfiguration = WineDisplayConfiguration.current(
			renderingMode: request.options.renderingMode,
			forceDisabled: request.forceDisableRetina,
			metalFXSupported: discovery.capabilities.metalFXSpatialUpscalingSupported
		)
		let environment = Self.runtimeEnvironmentOverrides(
			for: request.region,
			usesHardwareCursor: request.usesHardwareCursor,
			capabilities: discovery.capabilities
		)
		return PreparedLaunch(displayConfiguration: displayConfiguration, environment: environment)
	}

	/// Starts the game process. Returns nil when the session no longer owns the launch.
	private func spawn(_ context: LaunchContext, prepared: PreparedLaunch) async throws
		-> WineLaunch?
	{
		let request = context.request
		guard let spawnGate = session?.spawnGate, activeGameSessionID == request.id else {
			return nil
		}
		let launch = try await context.runtime.launch(
			gameExecutable: request.executable,
			prefixDirectory: request.prefixDirectory,
			gameArguments: ["-logFile", AppPaths.windowsUnityLogPath]
				+ (installation.configuration?.gameStartParams ?? [])
				+ request.options.playerArguments(
					gamePixelsPerPoint: prepared.displayConfiguration.gamePixelsPerPoint,
					fullscreenDisplay: GameFullscreenDisplay.primary
				),
			displayConfiguration: prepared.displayConfiguration,
			graphicsDiagnostics: graphicsDiagnosticsEnabled,
			metalPerformanceHUDEnabled: request.options.usesMetalPerformanceHUD,
			synchronizationMode: request.options.synchronizationMode,
			runtimeEnvironmentOverrides: prepared.environment,
			clientVariant: request.region.clientVariant,
			publisher: request.region.publisher,
			gameIconURL: customGameIconURL(),
			logURL: paths.runtimeLogFile(for: request.region),
			log: log,
			spawnGate: spawnGate
		)
		log.info(
			"Game runtime started; session=\(request.id.uuidString); pid=\(launch.processIdentifier); elapsed=\(Self.launchDuration(since: request.requestedAt))"
		)
		guard activeGameSessionID == request.id, !applicationTerminationRequested else {
			return nil
		}
		if Task.isCancelled {
			await stopAfterCancelledLaunch(
				runtime: context.runtime,
				sessionID: request.id,
				processIdentifier: launch.processIdentifier,
				region: request.region
			)
			return nil
		}
		return launch
	}

	/// Publishes the launching and running states once the process and its window are up.
	private func monitor(_ context: LaunchContext, launch: WineLaunch) async throws {
		let request = context.request
		if request.options.usesGameMode {
			GamePolicyControl.setGameMode(on: true, log: log)
		}
		updateSessionActivity(
			.launchingGame(sessionID: request.id, processIdentifier: launch.processIdentifier),
			lease: context.lease
		)
		lifecycle.setStatus(.startingGame)
		monitorGame(launch: launch, runtime: context.runtime, sessionID: request.id)
		try await WineWindowReadiness.wait(processIdentifier: launch.processIdentifier)
		guard activeGameSessionID == request.id, isGameActive, !applicationTerminationRequested
		else { return }
		updateSessionActivity(
			.runningGame(sessionID: request.id, processIdentifier: launch.processIdentifier),
			lease: context.lease
		)
		lifecycle.setStatus(.running)
		gameRunningSince = .now
		playtimeStatistics.start(sessionID: request.id, region: request.region)
		monitorGamePrefix(using: context.runtime, sessionID: request.id)
		log.info(
			"Game window became visible; session=\(request.id.uuidString); elapsed=\(Self.launchDuration(since: request.requestedAt))"
		)
	}
}
