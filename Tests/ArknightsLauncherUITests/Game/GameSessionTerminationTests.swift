// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation
@testable import ArknightsGameRuntime
@testable import ArknightsLauncherUI

@MainActor
struct GameSessionTerminationTests {
	@Test(.timeLimit(.minutes(1)))
	func cleanupRetainsPrefixOwnershipUntilStopSucceeds() async {
		let fixture = await makeFixture(region: .japan, maxStopAttempts: 1)
		let cleanup = Task {
			await fixture.model.gameSession.stopAndFinishGameSession(
				using: fixture.runtime,
				sessionID: fixture.sessionID,
				processIdentifier: 42,
				region: .japan,
				terminalFailure: GameSessionTerminalFailure(
					error: TestSessionError.crashed,
					operation: .runtimeExit,
					blocksGameLaunch: true
				)
			)
		}

		await fixture.runtime.waitForStop(attempt: 1)
		let duplicateCleanup = Task {
			await fixture.model.gameSession.stopAndFinishGameSession(
				using: fixture.runtime,
				sessionID: fixture.sessionID,
				processIdentifier: 42,
				region: .japan
			)
		}
		// The duplicate must not start a second stop. The fake throws on one, so a broken contract fails below.
		await duplicateCleanup.value
		#expect(await fixture.runtime.stopAttemptCount() == 1)
		#expect(
			fixture.model.lifecycle.activity
				== .stoppingGame(sessionID: fixture.sessionID, processIdentifier: 42)
		)
		#expect(!fixture.model.lifecycle.canBeginExclusiveActivity)
		await fixture.runtime.succeedStop(attempt: 1)
		await cleanup.value

		#expect(fixture.model.lifecycle.activity == .idle)
		#expect(
			fixture.model.lifecycle.state.presentation.failure?.context.operation == .runtimeExit)
		#expect(fixture.model.lifecycle.state.presentation.failure?.context.region == .japan)
		await fixture.api.resolveBranding()
	}

	@Test(.timeLimit(.minutes(1)))
	func failedStopRetriesTheSameSessionAndRetainsRecoveryAfterAnotherFailure() async {
		let fixture = await makeFixture(region: .korea)
		fixture.model.gameSession.runtimeSessionControllerProvider = { fixture.runtime }
		fixture.model.gameSession.stopGame()
		await fixture.runtime.waitForStop(attempt: 1)
		let firstCleanup = fixture.model.gameSession.session?.monitorTask
		await fixture.runtime.failStop(attempt: 1)
		await firstCleanup?.value

		#expect(
			fixture.model.lifecycle.activity
				== .stoppingGame(sessionID: fixture.sessionID, processIdentifier: 42)
		)
		#expect(fixture.model.lifecycle.state.presentation.failure?.id == fixture.sessionID)
		#expect(
			fixture.model.lifecycle.state.presentation.failure?.context.operation == .runtimeStop)
		#expect(fixture.model.lifecycle.state.presentation.failure?.context.region == .korea)
		#expect(
			fixture.model.lifecycle.state.presentation.failure?.actions.contains(.retry) == true)
		#expect(await fixture.runtime.stopAttemptCount() == 1)

		#expect(fixture.model.gameSession.retryRuntimeFailure(id: fixture.sessionID))
		#expect(!fixture.model.gameSession.retryRuntimeFailure(id: fixture.sessionID))
		await fixture.runtime.waitForStop(attempt: 2)
		let retryCount = await fixture.runtime.stopAttemptCount()
		#expect(retryCount == 2)
		let retryCleanup = fixture.model.gameSession.session?.monitorTask
		#expect(
			await fixture.runtime.stopDirectories() == [
				fixture.model.installation.paths.winePrefix(for: .korea),
				fixture.model.installation.paths.winePrefix(for: .korea),
			])
		await fixture.runtime.failStop(attempt: 2)
		await retryCleanup?.value

		#expect(
			fixture.model.lifecycle.activity
				== .stoppingGame(sessionID: fixture.sessionID, processIdentifier: 42)
		)
		#expect(fixture.model.lifecycle.state.presentation.failure?.id == fixture.sessionID)
		#expect(
			fixture.model.lifecycle.state.presentation.failure?.context.operation == .runtimeStop)
		#expect(fixture.model.lifecycle.state.presentation.failure?.context.region == .korea)
		#expect(
			fixture.model.lifecycle.state.presentation.failure?.actions.contains(.retry) == true)
		#expect(await fixture.runtime.stopAttemptCount() == 2)
		await fixture.api.resolveBranding()
	}
}

@MainActor
private func makeFixture(region: GameRegion, maxStopAttempts: Int = .max) async -> SessionFixture {
	let api = BlockingBrandingAPI()
	let model = makeModel(api: api, installer: ControllableInstaller())
	await api.waitForBrandingRequest()
	if model.installation.region != region {
		_ = model.installation.selectRegion(region)
	}
	let sessionID = UUID()
	model.beginTestGameSession(
		.runningGame(sessionID: sessionID, processIdentifier: 42), region: region)
	return SessionFixture(
		api: api, model: model,
		runtime: BlockingSessionRuntime(maxStopAttempts: maxStopAttempts), sessionID: sessionID)
}

private struct SessionFixture {
	let api: BlockingBrandingAPI
	let model: LauncherViewModel
	let runtime: BlockingSessionRuntime
	let sessionID: UUID
}

private enum TestSessionError: Error {
	case crashed
	case cleanupFailed
	case unexpectedStop
}

private actor BlockingSessionRuntime: WineRuntimeSessionControlling {
	private var stopContinuations: [Int: CheckedContinuation<Void, any Error>] = [:]
	private var requestedDirectories: [URL] = []
	private var startedSignals: [Int: Signal] = [:]
	/// Stop attempts beyond this count throw at once instead of suspending, so an unexpected stop fails.
	private let maxStopAttempts: Int

	init(maxStopAttempts: Int = .max) {
		self.maxStopAttempts = maxStopAttempts
	}

	func stop(prefixDirectory: URL, spawnGate: WineProcessSpawnGate?) async throws {
		requestedDirectories.append(prefixDirectory)
		let attempt = requestedDirectories.count
		guard attempt <= maxStopAttempts else { throw TestSessionError.unexpectedStop }
		try await withCheckedThrowingContinuation { continuation in
			stopContinuations[attempt] = continuation
			startedSignal(for: attempt).fire()
		}
	}

	func waitUntilStopped(prefixDirectory: URL) async throws {
	}

	/// Returns once `stop` has been called for `attempt`.
	func waitForStop(attempt: Int) async {
		await startedSignal(for: attempt).wait()
	}

	private func startedSignal(for attempt: Int) -> Signal {
		if let signal = startedSignals[attempt] { return signal }
		let signal = Signal()
		startedSignals[attempt] = signal
		return signal
	}

	func succeedStop(attempt: Int) {
		stopContinuations.removeValue(forKey: attempt)?.resume()
	}

	func failStop(attempt: Int) {
		stopContinuations.removeValue(forKey: attempt)?.resume(
			throwing: TestSessionError.cleanupFailed
		)
	}

	func stopAttemptCount() -> Int {
		requestedDirectories.count
	}

	func stopDirectories() -> [URL] {
		requestedDirectories
	}
}
