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
		lifecycle.activity = .runningGame(sessionID: sessionID, processIdentifier: 42)

		lifecycle.show(LauncherError.cannotSetAppIcon)

		#expect(lifecycle.activity == .runningGame(sessionID: sessionID, processIdentifier: 42))
		#expect(lifecycle.failureMessage == LauncherError.cannotSetAppIcon.errorDescription)
	}

	@Test(arguments: FailurePreservationScenario.allCases)
	func statusUpdatesFollowFailurePreservationRules(scenario: FailurePreservationScenario) {
		let lifecycle = makeLifecycleStore()
		var preflightFailure: LauncherFailurePresentation?
		switch scenario {
		case .ordinaryFailure:
			lifecycle.show(LauncherError.cannotSetAppIcon)
		case .rosettaPreflight:
			let failure = LauncherFailurePresentation(
				id: UUID(),
				message: "Rosetta is unavailable",
				code: .limpet,
				context: SupportContext(operation: .intelTranslationPreflight, region: nil),
				actions: [.retry],
				blocksGameLaunch: true
			)
			preflightFailure = failure
			lifecycle.presentFailure(failure, diagnostic: "preflight")
		}

		switch scenario {
		case .ordinaryFailure:
			lifecycle.setStatus(.ready, clearsFailure: false)
			#expect(lifecycle.failureMessage != nil)
			lifecycle.setStatus(.running)
			#expect(lifecycle.failure == nil)
			#expect(!lifecycle.activityMessage.isEmpty)
		case .rosettaPreflight:
			lifecycle.setStatus(.checking)
			lifecycle.setStatus(.ready)
			#expect(lifecycle.failure == preflightFailure)
		}
	}

	@Test(arguments: LauncherUpdateStartScenario.allCases)
	func launcherUpdateWaitsForAnActiveGameToFinish(scenario: LauncherUpdateStartScenario) {
		let lifecycle = makeLifecycleStore()
		let sessionID = UUID()
		let gameActivity = LauncherActivity.runningGame(
			sessionID: sessionID, processIdentifier: 42)
		if scenario == .gameRunning {
			lifecycle.activity = gameActivity
		}

		#expect(lifecycle.canBeginExclusiveActivity == (scenario == .idle))
		#expect(lifecycle.hasActiveActivity == (scenario == .gameRunning))
		lifecycle.beginLauncherUpdate()

		#expect(!lifecycle.canBeginExclusiveActivity)
		if scenario == .gameRunning {
			#expect(lifecycle.hasActiveActivity)
			#expect(lifecycle.activity == gameActivity)
			lifecycle.activity = .idle
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
}

enum FailurePreservationScenario: String, CaseIterable, Sendable {
	case ordinaryFailure
	case rosettaPreflight
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
