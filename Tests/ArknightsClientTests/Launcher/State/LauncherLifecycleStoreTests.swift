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
}

@MainActor
private func makeLifecycleStore() -> LauncherLifecycleStore {
	let fileURL = FileManager.default.temporaryDirectory.appending(
		path: "LauncherLifecycleStoreTests.\(UUID().uuidString).log"
	)
	return LauncherLifecycleStore(log: LauncherLog(fileURL: fileURL))
}
