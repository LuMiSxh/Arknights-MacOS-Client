// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@MainActor
struct LauncherLifecycleStoreTests {
	@Test
	func aPendingLauncherUpdateProjectsAsTheActivityOnlyBetweenOperations() throws {
		let storage = try TemporaryDirectory("LauncherLifecycleStoreTests")
		defer { storage.remove() }
		let lifecycle = makeLifecycleStore(in: storage)
		let gameActivity = LauncherActivity.runningGame(sessionID: UUID(), processIdentifier: 42)
		let lease = lifecycle.begin(gameActivity)

		lifecycle.beginLauncherUpdate()
		#expect(lifecycle.activity == gameActivity)
		#expect(lease.map { lifecycle.end($0) } == true)
		// The pending update keeps the launcher busy after the game lease ends.
		#expect(lifecycle.activity == .maintaining(.updatingLauncher))
		#expect(!lifecycle.canBeginExclusiveActivity)

		lifecycle.finishLauncherUpdate()
		#expect(lifecycle.activity == .idle)
	}
}
