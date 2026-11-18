// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
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
}
