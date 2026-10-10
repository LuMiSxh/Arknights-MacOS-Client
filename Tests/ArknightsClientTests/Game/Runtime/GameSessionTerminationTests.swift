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

		#expect(await fixture.runtime.waitForStop(attempt: 1))
		let duplicateCleanup = Task {
			await fixture.model.gameSession.stopAndFinishGameSession(
				using: fixture.runtime,
				sessionID: fixture.sessionID,
				processIdentifier: 42,
				region: .japan
			)
		}
		let duplicateStarted = await fixture.runtime.waitForStop(attempt: 2)
		#expect(!duplicateStarted)
		#expect(await fixture.runtime.stopAttemptCount() == 1)
		if duplicateStarted {
			await fixture.runtime.succeedStop(attempt: 2)
		}
		await duplicateCleanup.value
		#expect(
			fixture.model.lifecycle.activity
				== .stoppingGame(sessionID: fixture.sessionID, processIdentifier: 42)
		)
		#expect(!fixture.model.lifecycle.canBeginExclusiveActivity)
		await fixture.runtime.succeedStop(attempt: 1)
		await cleanup.value

		#expect(fixture.model.lifecycle.activity == .idle)
		#expect(fixture.model.lifecycle.failure?.context.operation == .runtimeExit)
		#expect(fixture.model.lifecycle.failure?.context.region == .japan)
		await fixture.api.resolveBranding()
	}

	@Test
	func failedStopRetriesTheSameSessionAndRetainsRecoveryAfterAnotherFailure() async {
		let fixture = await makeFixture(region: .korea)
		fixture.model.gameSession.runtimeSessionControllerProvider = { fixture.runtime }
		fixture.model.gameSession.stopGame()
		#expect(await fixture.runtime.waitForStop(attempt: 1))
		let firstCleanup = fixture.model.gameSession.session?.monitorTask
		await fixture.runtime.failStop(attempt: 1)
		await firstCleanup?.value

		#expect(
			fixture.model.lifecycle.activity
				== .stoppingGame(sessionID: fixture.sessionID, processIdentifier: 42)
		)
		#expect(fixture.model.lifecycle.failure?.id == fixture.sessionID)
		#expect(fixture.model.lifecycle.failure?.context.operation == .runtimeStop)
		#expect(fixture.model.lifecycle.failure?.context.region == .korea)
		#expect(fixture.model.lifecycle.failure?.actions.contains(.retry) == true)
		#expect(await fixture.runtime.stopAttemptCount() == 1)

		#expect(fixture.model.gameSession.retryRuntimeFailure(id: fixture.sessionID))
		#expect(!fixture.model.gameSession.retryRuntimeFailure(id: fixture.sessionID))
		let retryStarted = await fixture.runtime.waitForStop(attempt: 2)
		#expect(retryStarted)
		guard retryStarted else {
			await fixture.api.resolveBranding()
			return
		}
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
		#expect(fixture.model.lifecycle.failure?.id == fixture.sessionID)
		#expect(fixture.model.lifecycle.failure?.context.operation == .runtimeStop)
		#expect(fixture.model.lifecycle.failure?.context.region == .korea)
		#expect(fixture.model.lifecycle.failure?.actions.contains(.retry) == true)
		#expect(await fixture.runtime.stopAttemptCount() == 2)
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

		#expect(await fixture.runtime.waitForStop(attempt: 1))
		fixture.model.lifecycle.simulateActivity(
			.runningGame(sessionID: replacementSessionID, processIdentifier: 99))
		if let lease = fixture.model.gameSession.session?.lease {
			fixture.model.gameSession.session = ActiveGameSession(
				id: replacementSessionID,
				lease: lease,
				region: .global,
				spawnGate: WineProcessSpawnGate(),
				usesGameMode: false
			)
		}
		await fixture.runtime.succeedStop(attempt: 1)
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
	if model.installation.region != region {
		_ = model.installation.selectRegion(region)
	}
	let sessionID = UUID()
	model.beginTestGameSession(
		.runningGame(sessionID: sessionID, processIdentifier: 42), region: region)
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
	private var stopContinuations: [Int: CheckedContinuation<Void, any Error>] = [:]
	private var requestedDirectories: [URL] = []

	func stop(prefixDirectory: URL) async throws {
		requestedDirectories.append(prefixDirectory)
		let attempt = requestedDirectories.count
		try await withCheckedThrowingContinuation { stopContinuations[attempt] = $0 }
	}

	func waitUntilStopped(prefixDirectory: URL) async throws {
	}

	func waitForStop(attempt: Int) async -> Bool {
		for _ in 0..<100 {
			if stopContinuations[attempt] != nil { return true }
			try? await Task.sleep(for: .milliseconds(10))
		}
		return stopContinuations[attempt] != nil
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
