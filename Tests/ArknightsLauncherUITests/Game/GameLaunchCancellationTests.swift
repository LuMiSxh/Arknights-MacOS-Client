// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime
@testable import ArknightsLauncherUI

@MainActor
struct GameLaunchCancellationTests {
	/// Stands in for the launch steps: it waits for cancellation, then runs the same cleanup as
	/// `stopAfterCancelledLaunch` on the same session.
	private func cancellableLaunchTask(
		_ model: LauncherViewModel,
		runtime: ControlledLaunchRuntime,
		sessionID: UUID
	) -> Task<Void, Never> {
		Task {
			while !Task.isCancelled { await Task.yield() }
			await model.gameSession.stopAndFinishGameSession(
				using: runtime, sessionID: sessionID, processIdentifier: nil, region: .global)
		}
	}

	@Test(arguments: [
		LauncherActivity.preparingGame(sessionID: UUID()),
		.launchingGame(sessionID: UUID(), processIdentifier: nil),
	])
	func stopDuringLaunchStepsEndsIdleWithoutAnOrphanTask(activity: LauncherActivity) async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let sessionID = activity.activeGameSessionID ?? UUID()
		let spawnGate = WineProcessSpawnGate()
		let runtime = ControlledLaunchRuntime()
		model.beginTestGameSession(activity, spawnGate: spawnGate)
		let launch = cancellableLaunchTask(model, runtime: runtime, sessionID: sessionID)
		model.gameSession.session?.launchTask = launch

		model.gameSession.stopGame()

		#expect(launch.isCancelled)
		#expect(
			model.lifecycle.activity == .stoppingGame(sessionID: sessionID, processIdentifier: nil))
		#expect(throws: CancellationError.self) {
			try spawnGate.runIfAllowed(process: Process()) {}
		}
		#expect(await waitForCondition { runtime.isStopPending })
		runtime.finishStop()
		await launch.value

		#expect(runtime.stopCalls == 1)
		#expect(model.lifecycle.activity == .idle)
		#expect(model.gameSession.session == nil)
		await api.resolveBranding()
	}

	@Test
	func stopAfterTheProcessIsKnownCancelsTheLaunchTaskAndStopsThePrefix() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let sessionID = UUID()
		let runtime = ControlledLaunchRuntime()
		let launch = Task<Void, Never> {
			while !Task.isCancelled { await Task.yield() }
		}
		model.beginTestGameSession(
			.launchingGame(sessionID: sessionID, processIdentifier: 42), launchTask: launch)
		model.gameSession.runtimeSessionControllerProvider = { runtime }

		model.gameSession.stopGame()
		let cleanup = model.gameSession.session?.monitorTask
		#expect(await waitForCondition { runtime.isStopPending })
		#expect(launch.isCancelled)
		runtime.finishStop()
		await cleanup?.value
		await launch.value

		#expect(runtime.stopCalls == 1)
		#expect(model.lifecycle.activity == .idle)
		#expect(model.gameSession.session == nil)
		await api.resolveBranding()
	}
}
