// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Sparkle
import Testing

@testable import ArknightsLauncherUI

@MainActor
struct LauncherUpdaterControllerTests {
	@Test(arguments: UpdateLifecycleScenario.allCases)
	func exactSparkleCheckDelegateAllowsOnlyAnIdleLifecycle(
		scenario: UpdateLifecycleScenario
	) throws {
		let storage = try TemporaryDirectory("LauncherUpdaterControllerTests")
		defer { storage.remove() }
		let lifecycle = makeLifecycleStore(in: storage)
		lifecycle.simulateActivity(scenario.activity)
		let subject = LauncherUpdaterController(
			lifecycle: lifecycle,
			log: lifecycle.log
		)
		let sparkle = makeSparkleUpdater()

		if scenario.isBusy {
			#expect(throws: NSError.self) {
				try subject.updater(sparkle.1, mayPerform: .updates)
			}
		} else {
			try subject.updater(sparkle.1, mayPerform: .updates)
		}
	}

	@Test(arguments: UpdateLifecycleScenario.allCases)
	func relaunchIsPostponedOnlyUntilAnActiveLifecycleFinishes(
		scenario: UpdateLifecycleScenario
	) throws {
		let storage = try TemporaryDirectory("LauncherUpdaterControllerTests")
		defer { storage.remove() }
		let lifecycle = makeLifecycleStore(in: storage)
		lifecycle.simulateActivity(scenario.activity)
		let subject = LauncherUpdaterController(lifecycle: lifecycle, log: lifecycle.log)
		let sparkle = makeSparkleUpdater()
		var installCalled = false
		let postponed = subject.updater(
			sparkle.1,
			shouldPostponeRelaunchForUpdate: .empty(),
			untilInvokingBlock: { installCalled = true }
		)

		#expect(postponed == scenario.isBusy)
		if scenario.isBusy {
			lifecycle.simulateActivity(.idle)
			#expect(installCalled)
		}
		#expect(subject.updaterShouldRelaunchApplication(sparkle.1))

		var retryCount = 0
		let lease = lifecycle.begin(.runningGame(sessionID: UUID(), processIdentifier: 42))
		subject.userDriver.showInstallingUpdate(withApplicationTerminated: false) {
			retryCount += 1
		}
		#expect(retryCount == 0)
		#expect(lease.map { lifecycle.end($0) } == true)
		#expect(retryCount == 1)
	}

	@Test
	func exactSparkleAbortDelegateClearsPendingInstallAndDeferredWork() throws {
		let storage = try TemporaryDirectory("LauncherUpdaterControllerTests")
		defer { storage.remove() }
		let lifecycle = makeLifecycleStore(in: storage)
		lifecycle.beginLauncherUpdate()
		let subject = LauncherUpdaterController(lifecycle: lifecycle, log: lifecycle.log)
		let sparkle = makeSparkleUpdater()

		subject.updater(
			sparkle.1,
			didAbortWithError: NSError(domain: "Test", code: 1)
		)

		#expect(!lifecycle.isLauncherUpdatePending)
	}
}

@MainActor
private func makeSparkleUpdater() -> (SPUStandardUpdaterController, SPUUpdater) {
	let controller = SPUStandardUpdaterController(
		startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
	)
	return (controller, controller.updater)
}

enum UpdateLifecycleScenario: String, CaseIterable, Equatable, Sendable {
	case idle
	case gameRunning

	var activity: LauncherActivity {
		switch self {
		case .idle:
			.idle
		case .gameRunning:
			.runningGame(sessionID: UUID(), processIdentifier: 42)
		}
	}

	var isBusy: Bool { self == .gameRunning }
}
