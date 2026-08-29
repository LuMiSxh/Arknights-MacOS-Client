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

	@Test
	func statusClearsFailuresUnlessTheCallerPreservesThem() {
		let lifecycle = makeLifecycleStore()
		lifecycle.show(LauncherError.cannotSetAppIcon)

		lifecycle.setStatus(.ready, clearsFailure: false)
		#expect(lifecycle.failureMessage != nil)

		lifecycle.setStatus(.running)
		#expect(lifecycle.failureMessage == nil)
		#expect(lifecycle.activityMessage == L10n.string(.Launcher.launcherStatusRunning))
	}

	@Test
	func idleLifecycleAllowsLauncherUpdateActivity() {
		let lifecycle = makeLifecycleStore()

		#expect(lifecycle.canBeginExclusiveActivity)
		#expect(!lifecycle.hasActiveActivity)

		lifecycle.beginLauncherUpdate()
		#expect(!lifecycle.canBeginExclusiveActivity)
		#expect(lifecycle.activity == .maintaining(.updatingLauncher))
	}

	@Test
	func pendingLauncherUpdateWaitsForActiveActivityToFinish() {
		let lifecycle = makeLifecycleStore()
		let sessionID = UUID()
		lifecycle.activity = .runningGame(sessionID: sessionID, processIdentifier: 42)
		lifecycle.beginLauncherUpdate()

		#expect(!lifecycle.canBeginExclusiveActivity)
		#expect(lifecycle.hasActiveActivity)
		#expect(lifecycle.activity == .runningGame(sessionID: sessionID, processIdentifier: 42))

		lifecycle.activity = .idle
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
		actions: [.showLogs, .openTroubleshooting, .reportProblem]
	)
}
