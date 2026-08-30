// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct GameSessionTerminationTests {
	@Test
	func cleanupRetainsPrefixOwnershipUntilStopSucceeds() async {
		let fixture = await makeFixture(region: .japan)
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

		await fixture.runtime.waitForStop()
		#expect(
			fixture.model.lifecycle.activity
				== .stoppingGame(sessionID: fixture.sessionID, processIdentifier: 42)
		)
		#expect(!fixture.model.lifecycle.canBeginExclusiveActivity)
		await fixture.runtime.succeedStop()
		await cleanup.value

		#expect(fixture.model.lifecycle.activity == .idle)
		#expect(fixture.model.lifecycle.failure?.context.operation == .runtimeExit)
		#expect(fixture.model.lifecycle.failure?.context.region == .japan)
		await fixture.api.resolveBranding()
	}

	@Test
	func stopFailureKeepsTheSessionOwnedAndOffersRuntimeStopRecovery() async {
		let fixture = await makeFixture(region: .korea)
		let cleanup = Task {
			await fixture.model.gameSession.stopAndFinishGameSession(
				using: fixture.runtime,
				sessionID: fixture.sessionID,
				processIdentifier: 42,
				region: .korea
			)
		}

		await fixture.runtime.waitForStop()
		await fixture.runtime.failStop()
		await cleanup.value

		#expect(
			fixture.model.lifecycle.activity
				== .stoppingGame(sessionID: fixture.sessionID, processIdentifier: 42)
		)
		#expect(fixture.model.lifecycle.failure?.id == fixture.sessionID)
		#expect(fixture.model.lifecycle.failure?.context.operation == .runtimeStop)
		#expect(fixture.model.lifecycle.failure?.context.region == .korea)
		#expect(fixture.model.lifecycle.failure?.actions.contains(.retry) == true)
		await fixture.api.resolveBranding()
	}

	@Test
	func staleCleanupCannotFinishOrFailAReplacementSession() async {
		let fixture = await makeFixture(region: .japan)
		let replacementSessionID = UUID()
		let cleanup = Task {
			await fixture.model.gameSession.stopAndFinishGameSession(
				using: fixture.runtime,
				sessionID: fixture.sessionID,
				processIdentifier: 42,
				region: .japan,
				terminalFailure: GameSessionTerminalFailure(
					error: TestSessionError.crashed,
					operation: .runtimeExit,
					blocksGameLaunch: false
				)
			)
		}

		await fixture.runtime.waitForStop()
		fixture.model.lifecycle.activity = .runningGame(
			sessionID: replacementSessionID,
			processIdentifier: 99
		)
		fixture.model.gameSession.activeGameRegion = .global
		await fixture.runtime.succeedStop()
		await cleanup.value

		#expect(
			fixture.model.lifecycle.activity
				== .runningGame(sessionID: replacementSessionID, processIdentifier: 99)
		)
		#expect(fixture.model.lifecycle.failure == nil)
		await fixture.api.resolveBranding()
	}
}

@MainActor
private func makeFixture(region: GameRegion) async -> SessionFixture {
	let api = BlockingBrandingAPI()
	let model = makeModel(api: api, installer: ControllableInstaller())
	await api.waitForBrandingRequest()
	let sessionID = UUID()
	model.lifecycle.activity = .runningGame(sessionID: sessionID, processIdentifier: 42)
	model.gameSession.activeGameRegion = region
	return SessionFixture(
		api: api, model: model, runtime: BlockingSessionRuntime(), sessionID: sessionID)
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
}

private actor BlockingSessionRuntime: WineRuntimeSessionControlling {
	private var stopContinuation: CheckedContinuation<Void, any Error>?
	private var stopWaiters: [CheckedContinuation<Void, Never>] = []

	func stop(prefixDirectory: URL) async throws {
		for waiter in stopWaiters { waiter.resume() }
		stopWaiters.removeAll()
		try await withCheckedThrowingContinuation { stopContinuation = $0 }
	}

	func waitUntilStopped(prefixDirectory: URL) async throws {
	}

	func waitForStop() async {
		if stopContinuation != nil { return }
		await withCheckedContinuation { stopWaiters.append($0) }
	}

	func succeedStop() {
		stopContinuation?.resume()
		stopContinuation = nil
	}

	func failStop() {
		stopContinuation?.resume(throwing: TestSessionError.cleanupFailed)
		stopContinuation = nil
	}
}
