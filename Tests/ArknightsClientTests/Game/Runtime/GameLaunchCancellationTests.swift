// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

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

	@Test
	func aSecondStopWhileCleanupRunsDoesNotStartAnotherStop() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let sessionID = UUID()
		let runtime = ControlledLaunchRuntime()
		model.beginTestGameSession(.preparingGame(sessionID: sessionID))
		let first = Task {
			await model.gameSession.stopAndFinishGameSession(
				using: runtime, sessionID: sessionID, processIdentifier: nil, region: .global)
		}
		#expect(await waitForCondition { runtime.isStopPending })

		await model.gameSession.stopAndFinishGameSession(
			using: runtime, sessionID: sessionID, processIdentifier: nil, region: .global)
		runtime.finishStop()
		await first.value

		#expect(runtime.stopCalls == 1)
		#expect(model.lifecycle.activity == .idle)
		await api.resolveBranding()
	}

	@Test(arguments: [Duration.seconds(1), .seconds(90)])
	func windowReadinessTimesOutOnAManualClockWithoutSleeping(timeout: Duration) async {
		let clock = ManualClock()
		let pollInterval = Duration.milliseconds(250)

		await #expect {
			// No process has this identifier, so no window ever becomes visible.
			try await WineWindowReadiness.wait(
				processIdentifier: Int32.max - 1, timeout: timeout, pollInterval: pollInterval,
				clock: clock)
		} throws: { error in
			if case GameRuntimeError.runtimeWindowTimeout = error { true } else { false }
		}

		#expect(clock.now.offset >= timeout)
		#expect(clock.sleepCount >= Int(timeout / pollInterval))
	}

	@Test
	func windowReadinessPropagatesCancellationFromTheClock() async {
		let clock = ManualClock()
		let wait = Task {
			try await WineWindowReadiness.wait(
				processIdentifier: Int32.max - 1, timeout: .seconds(90),
				pollInterval: .milliseconds(250), clock: clock)
		}
		wait.cancel()

		await #expect(throws: CancellationError.self) { try await wait.value }
	}
}
