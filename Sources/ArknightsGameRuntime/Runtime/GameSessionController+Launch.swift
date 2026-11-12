// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

extension GameSessionController {
	package func launch() {
		guard lifecycle.activity == .idle, !applicationTerminationRequested,
			pendingLaunchID == nil
		else { return }
		let region = installation.region
		let lane = currentRuntimeLane()
		let usesBatterySaver = settings.batterySaverEnabled
		let launchOptions = settings.launchOptions.yieldingToGameSettings()
		let request = LaunchRequest(
			id: UUID(),
			region: region,
			lane: lane,
			executable: installation.installDirectory.appending(
				path: installation.configuration?.executableName ?? "Arknights.exe"
			),
			prefixDirectory: paths.winePrefix(for: region, lane: lane),
			options: usesBatterySaver
				? launchOptions.applyingBatterySaver(
					metalFXSupported: metalFXSpatialUpscalingSupported ?? false)
				: launchOptions,
			frameRateCap: settings.launchOptions.frameRateCap(
				batterySaverLimit: usesBatterySaver ? settings.batterySaverFrameRateLimit : nil),
			usesBatterySaver: usesBatterySaver,
			disabledRuntimePatches: settings.disabledRuntimePatches,
			usesDebugLogging: settings.debugLoggingEnabled,
			usesHardwareCursor: settings.usesHardwareCursor,
			forceDisableRetina: preferences.forceDisableRetina(),
			requestedAt: .now
		)
		// The session does not exist until the preflight finishes. This marker keeps a second
		// Play click from starting a second launch in that window.
		pendingLaunchID = request.id
		Task { [weak self] in
			await self?.startLaunch(request)
		}
	}

	// Cleans up from a cancelled launch task without inheriting its cancellation, which would
	// otherwise abort the `wineserver -k` call itself.
	func stopAfterCancelledLaunch(
		runtime: WineRuntime,
		sessionID: UUID,
		processIdentifier: Int32?,
		region: GameRegion
	) async {
		await Task { @MainActor in
			await stopAndFinishGameSession(
				using: runtime,
				sessionID: sessionID,
				processIdentifier: processIdentifier,
				region: region
			)
		}.value
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
				error: GameRuntimeError.runtimeWindowTimeout,
				operation: .launch,
				blocksGameLaunch: true
			)
		)
	}
}
