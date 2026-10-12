// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
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
		let lifecycle = makeLifecycleStore()
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
	) {
		let lifecycle = makeLifecycleStore()
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
	func exactSparkleAbortDelegateClearsPendingInstallAndDeferredWork() {
		let lifecycle = makeLifecycleStore()
		lifecycle.beginLauncherUpdate()
		let subject = LauncherUpdaterController(lifecycle: lifecycle, log: lifecycle.log)
		let sparkle = makeSparkleUpdater()

		subject.updater(
			sparkle.1,
			didAbortWithError: NSError(domain: "Test", code: 1)
		)

		#expect(!lifecycle.isLauncherUpdatePending)
	}

	@Test
	func sparkleNoUpdateErrorCountsAsCurrentForSilentProbe() {
		let error = NSError(
			domain: SUSparkleErrorDomain,
			code: Int(SUError.noUpdateError.rawValue)
		)

		#expect(LauncherUpdaterController.isNoUpdateError(error))
		#expect(
			!LauncherUpdaterController.isNoUpdateError(
				NSError(
					domain: SUSparkleErrorDomain,
					code: Int(SUError.appcastError.rawValue)
				)
			)
		)

		for (probeError, expected) in [
			(error, LauncherUpdateCheckOutcome.current),
			(NSError(domain: "Test", code: 1), .failed),
		] {
			let subject = makeUpdater()
			var outcome: LauncherUpdateCheckOutcome?
			subject.beginProbeForTesting { outcome = $0 }
			subject.updater(makeSparkleUpdater().1, didAbortWithError: probeError)
			#expect(outcome == nil)
			#expect(subject.userDriver.phase == .hidden)
			subject.updater(
				makeSparkleUpdater().1, didFinishUpdateCycleFor: .updateInformation,
				error: probeError)
			#expect(outcome == expected)
			#expect(subject.userDriver.phase == .hidden)
		}
	}
}

@MainActor
private func makeSparkleUpdater() -> (SPUStandardUpdaterController, SPUUpdater) {
	let controller = SPUStandardUpdaterController(
		startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
	)
	return (controller, controller.updater)
}

@MainActor
private func makeUpdater() -> LauncherUpdaterController {
	let lifecycle = makeLifecycleStore()
	return LauncherUpdaterController(lifecycle: lifecycle, log: lifecycle.log)
}

@MainActor
private func makeLifecycleStore() -> LauncherLifecycleStore {
	let fileURL = FileManager.default.temporaryDirectory.appending(
		path: "LauncherUpdaterControllerTests.\(UUID().uuidString).log"
	)
	return LauncherLifecycleStore(log: LauncherLog(fileURL: fileURL))
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
