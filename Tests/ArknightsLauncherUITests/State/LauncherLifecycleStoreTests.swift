// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import Foundation
import Testing

@testable import ArknightsLauncherUI

@MainActor
struct LauncherLifecycleStoreTests {
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
