// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

extension GameSessionController {
	static func runtimeEnvironmentOverrides(
		for region: GameRegion,
		usesHardwareCursor: Bool,
		displayMode: GameDisplayMode,
		features: RuntimeFeatures = .conservative
	) -> [String: String] {
		var environment = [
			AppConstants.Runtime.masterEnvironmentKey: "1"
		]
		environment.merge(region.runtimeEnvironmentOverrides) { _, profileValue in profileValue }
		environment.merge(
			features.environmentOverrides(
				usesHardwareCursor: usesHardwareCursor,
				displayMode: displayMode
			)
		) { _, value in value }
		return environment
	}

	package func launch() {
		guard lifecycle.activity == .idle, !applicationTerminationRequested,
			pendingLaunchID == nil
		else { return }
		let region = installation.region
		let usesBatterySaver = settings.batterySaverEnabled
		let request = LaunchRequest(
			id: UUID(),
			region: region,
			executable: installation.installDirectory.appending(
				path: installation.configuration?.executableName ?? "Arknights.exe"
			),
			prefixDirectory: paths.winePrefix(for: region),
			options: usesBatterySaver
				? settings.launchOptions.applyingBatterySaver(
					frameRateLimit: settings.batterySaverFrameRateLimit,
					metalFXSupported: metalFXSpatialUpscalingSupported ?? false)
				: settings.launchOptions,
			usesBatterySaver: usesBatterySaver,
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
