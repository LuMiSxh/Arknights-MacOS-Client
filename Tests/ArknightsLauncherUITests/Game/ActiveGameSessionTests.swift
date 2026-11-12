// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime
@testable import ArknightsLauncherUI

extension LauncherViewModel {
	/// Begins `activity` and installs the matching `ActiveGameSession` on the game controller.
	@discardableResult
	func beginTestGameSession(
		_ activity: LauncherActivity,
		region: GameRegion = .global,
		lane: RuntimeLane? = nil,
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
			lane: lane ?? paths.runtimeLane,
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

	@Test
	func changingTheProviderLaneResolvesTheNewRuntimeAndPrefix() async throws {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let configuration = try makeRuntimeConfiguration(
			x86: makeRuntimeLane(version: "1.0.0"),
			arm: makeRuntimeLane(version: "2.0.0", minimumMacOS: "26.0"))
		model.gameSession.currentRuntimeLane = { .arm }

		let lane = model.gameSession.currentRuntimeLane()
		let directory = try GameSessionController.pinnedRuntimeVersionDirectory(
			paths: model.gameSession.paths, lane: lane, configuration: configuration)

		#expect(model.paths.runtimeLane == .x86)
		#expect(lane == .arm)
		#expect(directory == model.paths.runtimeVersionDirectory(for: .arm, version: "2.0.0"))
		#expect(
			model.paths.winePrefix(for: .global, lane: lane)
				!= model.paths.winePrefix(for: .global, lane: .x86))
		await api.resolveBranding()
	}
}

/// Records whether the spawn gate already refused new processes when `stop` ran.
private final class GateRecordingRuntime: WineRuntimeSessionControlling, @unchecked Sendable {
	private let lock = NSLock()
	private var denied: Bool?

	var spawnWasDeniedAtStop: Bool? {
		lock.withLock { denied }
	}

	func waitUntilStopped(prefixDirectory: URL) async throws {}

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
