// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherLifecycleStoreTests {
	@Test
	func presentationChangesDoNotReplaceActiveGameActivity() {
		let lifecycle = makeLifecycleStore()
		let sessionID = UUID()
		let lease = lifecycle.begin(.runningGame(sessionID: sessionID, processIdentifier: 42))
		#expect(lease != nil)

		lifecycle.show(CustomizationError.cannotSetAppIcon)

		#expect(lifecycle.activity == .runningGame(sessionID: sessionID, processIdentifier: 42))
		#expect(lifecycle.failureMessage == CustomizationError.cannotSetAppIcon.errorDescription)
	}

	@Test
	func statusClearsFailuresUnlessTheCallerPreservesThem() {
		let lifecycle = makeLifecycleStore()
		lifecycle.show(CustomizationError.cannotSetAppIcon)

		lifecycle.setStatus(.ready, clearsFailure: false)
		#expect(lifecycle.failureMessage != nil)

		lifecycle.setStatus(.running)
		#expect(lifecycle.failureMessage == nil)
		#expect(!lifecycle.activityMessage.isEmpty)
	}

	@Test
	func statusUpdatesKeepRosettaPreflightFailureUntilItsCheckSucceeds() {
		let lifecycle = makeLifecycleStore()
		let failure = LauncherFailurePresentation(
			id: UUID(),
			message: "Rosetta is unavailable",
			code: .limpet,
			context: SupportContext(operation: .intelTranslationPreflight, region: nil),
			actions: [.retry],
			blocksGameLaunch: true
		)
		lifecycle.presentFailure(failure, diagnostic: "preflight")

		lifecycle.setStatus(.checking)
		lifecycle.setStatus(.ready)

		#expect(lifecycle.failure == failure)
	}

	@Test(arguments: LauncherUpdateStartScenario.allCases)
	func launcherUpdateWaitsForAnActiveGameToFinish(scenario: LauncherUpdateStartScenario) {
		let lifecycle = makeLifecycleStore()
		let sessionID = UUID()
		let gameActivity = LauncherActivity.runningGame(
			sessionID: sessionID, processIdentifier: 42)
		var gameLease: ActivityLease?
		if scenario == .gameRunning {
			gameLease = lifecycle.begin(gameActivity)
			#expect(gameLease != nil)
		}

		#expect(lifecycle.canBeginExclusiveActivity == (scenario == .idle))
		#expect(lifecycle.hasActiveActivity == (scenario == .gameRunning))
		lifecycle.beginLauncherUpdate()

		#expect(!lifecycle.canBeginExclusiveActivity)
		if scenario == .gameRunning {
			#expect(lifecycle.hasActiveActivity)
			#expect(lifecycle.activity == gameActivity)
			#expect(gameLease.map { lifecycle.end($0) } == true)
		}
		#expect(lifecycle.activity == .maintaining(.updatingLauncher))
		#expect(!lifecycle.canBeginExclusiveActivity)

		lifecycle.finishLauncherUpdate()
		#expect(lifecycle.activity == .idle)
		#expect(lifecycle.canBeginExclusiveActivity)
	}

	@Test
	func duplicatePresentationAndConsumptionAreIdempotent() {
		let lifecycle = makeLifecycleStore()
		let failure = testFailure(id: UUID(), message: "failure")
		#expect(lifecycle.presentFailure(failure, diagnostic: "first"))
		#expect(!lifecycle.presentFailure(failure, diagnostic: "duplicate"))

		#expect(lifecycle.consumeFailure(id: UUID()) == nil)
		#expect(lifecycle.consumeFailure(id: failure.id) == failure)
		#expect(lifecycle.consumeFailure(id: failure.id) == nil)
	}

	@Test
	func staleLeaseEndDoesNotIdleANewerOperation() {
		let lifecycle = makeLifecycleStore()
		let earlier = lifecycle.begin(.maintaining(.clearingCache))
		#expect(earlier != nil)
		lifecycle.simulateActivity(.idle)
		let newer = lifecycle.begin(.installing(id: UUID(), stage: .downloading))
		#expect(newer != nil)

		#expect(earlier.map { lifecycle.end($0) } == false)
		#expect(earlier.map { lifecycle.update($0, to: .idle) } == false)

		#expect(lifecycle.hasActiveActivity)
		#expect(newer.map { lifecycle.end($0) } == true)
		#expect(lifecycle.activity == .idle)
	}
}

enum LauncherUpdateStartScenario: String, CaseIterable, Equatable, Sendable {
	case idle
	case gameRunning
}

@MainActor
private func makeLifecycleStore() -> LauncherLifecycleStore {
	let fileURL = FileManager.default.temporaryDirectory.appending(
		path: "LauncherLifecycleStoreTests.\(UUID().uuidString).log"
	)
	return LauncherLifecycleStore(log: LauncherLog(fileURL: fileURL))
}

private func testFailure(id: UUID, message: String) -> LauncherFailurePresentation {
	LauncherFailurePresentation(
		id: id,
		message: message,
		code: .virga,
		context: SupportContext(operation: .launcher, region: nil),
		actions: [.openTroubleshooting, .reportProblem]
	)
}
