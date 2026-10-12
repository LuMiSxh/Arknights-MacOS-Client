// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime
@testable import ArknightsLauncherUI

@MainActor
struct GameLaunchOwnershipTests {
	@Test
	func secondPlayClickDuringPreflightStartsOnlyOneLaunch() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()

		model.gameSession.launch()
		let pendingID = model.gameSession.pendingLaunchID
		model.gameSession.launch()
		model.gameSession.launch()

		#expect(pendingID != nil)
		#expect(model.gameSession.pendingLaunchID == pendingID)
		// The game is not installed, so the one launch ends with a single failure for its ID.
		#expect(await waitForCondition { model.gameSession.pendingLaunchID == nil })
		#expect(model.lifecycle.state.presentation.failure?.id == pendingID)
		#expect(model.gameSession.session == nil)
		#expect(model.lifecycle.activity == .idle)

		// A session that already owns the launcher ignores further launches.
		let owned = LauncherActivity.runningGame(sessionID: UUID(), processIdentifier: 7)
		model.beginTestGameSession(owned)
		model.gameSession.launch()
		#expect(model.gameSession.pendingLaunchID == nil)
		#expect(model.lifecycle.activity == owned)
		await api.resolveBranding()
	}

	@Test
	func idleIsPublishedOnlyAfterWaitUntilStoppedReturns() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let sessionID = UUID()
		let activity = LauncherActivity.runningGame(sessionID: sessionID, processIdentifier: 42)
		model.beginTestGameSession(activity)
		let runtime = ControlledLaunchRuntime(blocksWait: true)

		model.gameSession.monitorGamePrefix(using: runtime, sessionID: sessionID)
		let monitor = model.gameSession.session?.monitorTask
		#expect(await waitForCondition { runtime.isWaitPending })
		#expect(model.lifecycle.activity == activity)

		runtime.finishWait()
		await monitor?.value

		#expect(model.lifecycle.activity == .idle)
		#expect(model.gameSession.session == nil)
		await api.resolveBranding()
	}

	@Test
	func shieldedStopCompletesAfterTheOwningTaskIsCancelled() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let sessionID = UUID()
		model.beginTestGameSession(.runningGame(sessionID: sessionID, processIdentifier: 42))
		let runtime = ControlledLaunchRuntime()
		let owner = Task {
			await model.gameSession.stopAndFinishGameSession(
				using: runtime, sessionID: sessionID, processIdentifier: 42, region: .global)
		}
		#expect(await waitForCondition { runtime.isStopPending })

		owner.cancel()
		// The prefix is still owned while the cancelled owner waits for the shielded stop.
		#expect(!model.lifecycle.canBeginExclusiveActivity)
		runtime.finishStop()
		await owner.value

		#expect(!runtime.stopSawCancellation)
		#expect(runtime.stopCalls == 1)
		#expect(model.lifecycle.activity == .idle)
		await api.resolveBranding()
	}
}
