// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

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
		#expect(model.lifecycle.failure?.id == pendingID)
		#expect(model.gameSession.session == nil)
		#expect(model.lifecycle.activity == .idle)
		await api.resolveBranding()
	}

	@Test
	func aFinishedPreflightAllowsTheNextLaunch() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()

		model.gameSession.launch()
		let firstID = model.gameSession.pendingLaunchID
		#expect(await waitForCondition { model.gameSession.pendingLaunchID == nil })
		_ = model.lifecycle.consumeFailure(id: firstID ?? UUID())
		model.gameSession.launch()

		#expect(model.gameSession.pendingLaunchID != nil)
		#expect(model.gameSession.pendingLaunchID != firstID)
		#expect(await waitForCondition { model.gameSession.pendingLaunchID == nil })
		await api.resolveBranding()
	}

	@Test(arguments: [
		LauncherActivity.runningGame(sessionID: UUID(), processIdentifier: 7),
		.preparingGame(sessionID: UUID()),
		.stoppingGame(sessionID: UUID(), processIdentifier: nil),
	])
	func launchIsIgnoredWhileAnotherSessionOwnsTheLauncher(activity: LauncherActivity) async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		model.beginTestGameSession(activity)

		model.gameSession.launch()

		#expect(model.gameSession.pendingLaunchID == nil)
		#expect(model.lifecycle.activity == activity)
		await api.resolveBranding()
	}

	@Test
	func staleSessionIDNeverStopsOrIdlesTheLiveSession() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let sessionID = UUID()
		let activity = LauncherActivity.runningGame(sessionID: sessionID, processIdentifier: 42)
		model.beginTestGameSession(activity)
		let runtime = ControlledLaunchRuntime()

		await model.gameSession.stopAndFinishGameSession(
			using: runtime, sessionID: UUID(), processIdentifier: 42, region: .global)
		model.gameSession.finishGameSession(UUID())

		#expect(runtime.stopCalls == 0)
		#expect(model.lifecycle.activity == activity)
		#expect(model.gameSession.session?.id == sessionID)
		await api.resolveBranding()
	}

	@Test
	func staleLeaseCannotUpdateOrEndAReplacementActivity() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let oldID = UUID()
		let oldLease = model.lifecycle.begin(.preparingGame(sessionID: oldID))
		#expect(oldLease.map { model.lifecycle.end($0) } == true)
		let newActivity = LauncherActivity.runningGame(sessionID: UUID(), processIdentifier: 9)
		_ = model.lifecycle.begin(newActivity)

		if let oldLease {
			#expect(!model.lifecycle.end(oldLease))
			#expect(!model.lifecycle.update(oldLease, to: .idle))
		}

		#expect(model.lifecycle.activity == newActivity)
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
