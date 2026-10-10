// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

extension LauncherViewModel {
	/// Begins `activity` and installs the matching `ActiveGameSession` on the game controller.
	@discardableResult
	func beginTestGameSession(
		_ activity: LauncherActivity,
		region: GameRegion = .global,
		spawnGate: WineProcessSpawnGate = WineProcessSpawnGate(),
		launchTask: Task<Void, Never>? = nil
	) -> ActiveGameSession? {
		guard let sessionID = activity.activeGameSessionID, let lease = lifecycle.begin(activity)
		else {
			Issue.record("Could not begin a test game session for \(activity).")
			return nil
		}
		var session = ActiveGameSession(
			id: sessionID,
			lease: lease,
			region: region,
			spawnGate: spawnGate,
			usesGameMode: false
		)
		session.launchTask = launchTask
		gameSession.session = session
		return session
	}
}

@MainActor
struct ActiveGameSessionTests {
	@Test
	func finishingASessionClearsEveryField() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let sessionID = UUID()
		let launch = Task<Void, Never> {
			while !Task.isCancelled { await Task.yield() }
		}
		let monitor = Task<Void, Never> {
			while !Task.isCancelled { await Task.yield() }
		}
		model.beginTestGameSession(
			.runningGame(sessionID: sessionID, processIdentifier: 42),
			region: .japan,
			launchTask: launch
		)
		model.gameSession.session?.monitorTask = monitor
		model.gameSession.session?.pendingTerminalFailure = GameSessionTerminalFailure(
			error: SessionTestError.crashed,
			operation: .runtimeExit,
			blocksGameLaunch: false
		)
		model.gameSession.session?.isRuntimeStopInFlight = true

		model.gameSession.finishGameSession(sessionID)
		await launch.value
		await monitor.value

		#expect(model.gameSession.session == nil)
		#expect(model.gameSession.sessionLease == nil)
		#expect(model.gameSession.activeGameRegion == nil)
		#expect(launch.isCancelled)
		#expect(monitor.isCancelled)
		#expect(model.lifecycle.activity == .idle)
		await api.resolveBranding()
	}

	@Test
	func staleSessionIDCannotFinishANewerSession() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let sessionID = UUID()
		model.beginTestGameSession(
			.runningGame(sessionID: sessionID, processIdentifier: 42), region: .korea)

		model.gameSession.finishGameSession(UUID())

		#expect(model.gameSession.session?.id == sessionID)
		#expect(model.gameSession.activeGameRegion == .korea)
		#expect(
			model.lifecycle.activity
				== .runningGame(sessionID: sessionID, processIdentifier: 42))
		await api.resolveBranding()
	}

	@Test
	func stopDeniesTheSpawnGateBeforeRuntimeStopRuns() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let sessionID = UUID()
		let spawnGate = WineProcessSpawnGate()
		model.beginTestGameSession(
			.runningGame(sessionID: sessionID, processIdentifier: 42),
			spawnGate: spawnGate
		)
		let runtime = GateRecordingRuntime()
		model.gameSession.runtimeSessionControllerProvider = { runtime }

		model.gameSession.stopGame()
		await model.gameSession.session?.monitorTask?.value

		#expect(runtime.spawnWasDeniedAtStop == true)
		#expect(model.lifecycle.activity == .idle)
		await api.resolveBranding()
	}
}

private enum SessionTestError: Error {
	case crashed
}

/// Records whether the spawn gate already refused new processes when `stop` ran.
private final class GateRecordingRuntime: WineRuntimeSessionControlling, @unchecked Sendable {
	private let lock = NSLock()
	private var denied: Bool?

	var spawnWasDeniedAtStop: Bool? {
		lock.withLock { denied }
	}

	func waitUntilStopped(prefixDirectory: URL) async throws {}

	func stop(prefixDirectory: URL) async throws {}

	func stop(prefixDirectory: URL, spawnGate: WineProcessSpawnGate?) async throws {
		var wasDenied = false
		do {
			try spawnGate?.runIfAllowed(process: Process()) {}
		} catch is CancellationError {
			wasDenied = true
		}
		lock.withLock { denied = wasDenied }
	}
}
