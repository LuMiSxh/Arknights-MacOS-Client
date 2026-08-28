// SPDX-License-Identifier: MPL-2.0

import Foundation
import Sparkle
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherUpdaterControllerTests {
	@Test
	func exactSparkleCheckDelegateAllowsAnIdleLifecycle() throws {
		let subject = makeUpdater()
		let sparkle = makeSparkleUpdater()

		try subject.updater(sparkle.1, mayPerform: .updates)
	}

	@Test
	func exactSparkleCheckDelegateThrowsWhileLifecycleIsBusy() {
		let lifecycle = makeLifecycleStore()
		lifecycle.activity = .runningGame(sessionID: UUID(), processIdentifier: 42)
		let subject = LauncherUpdaterController(
			lifecycle: lifecycle,
			log: lifecycle.log
		)
		let sparkle = makeSparkleUpdater()

		#expect(throws: NSError.self) {
			try subject.updater(sparkle.1, mayPerform: .updates)
		}
	}

	@Test
	func relaunchPermissionDoesNotPreemptDeferredLifecycleHandling() {
		let subject = makeUpdater()
		let sparkle = makeSparkleUpdater()

		#expect(subject.updaterShouldRelaunchApplication(sparkle.1))
	}

	@Test
	func relaunchIsNotPostponedWhenTheLifecycleIsIdle() {
		let subject = makeUpdater()
		let sparkle = makeSparkleUpdater()

		#expect(
			!subject.updater(
				sparkle.1,
				shouldPostponeRelaunchForUpdate: .empty(),
				untilInvokingBlock: {}
			)
		)
	}

	@Test
	func hiddenActiveUpdateRemainsOpenableWhileLifecycleGateIsHeld() {
		let lifecycle = makeLifecycleStore()
		lifecycle.beginLauncherUpdate()
		var activationCount = 0
		let subject = LauncherUpdaterController(
			lifecycle: lifecycle,
			log: lifecycle.log,
			activateApplication: { activationCount += 1 }
		)
		subject.userDriver.showReady { _ in }
		subject.userDriver.dismissFromUser()

		#expect(subject.canOpenUpdate)
		subject.checkForUpdates()

		#expect(subject.userDriver.isPresented)
		#expect(activationCount == 1)
	}

	@Test
	func hiddenUpdateActionRefocusesReadyAndInstallingPhases() {
		let lifecycle = makeLifecycleStore()
		var activationCount = 0
		let subject = LauncherUpdaterController(
			lifecycle: lifecycle,
			log: lifecycle.log,
			activateApplication: { activationCount += 1 }
		)

		subject.userDriver.showReady { _ in }
		subject.userDriver.dismissFromUser()
		#expect(subject.userDriver.phase == .readyToInstall)
		#expect(!subject.userDriver.isPresented)

		subject.checkForUpdates()

		#expect(subject.userDriver.isPresented)
		#expect(activationCount == 1)

		subject.userDriver.dismissUpdateInstallation()
		subject.userDriver.showInstallingUpdate(withApplicationTerminated: true) {}
		subject.userDriver.dismissFromUser()
		subject.checkForUpdates()

		#expect(subject.userDriver.phase == .installing)
		#expect(subject.userDriver.isPresented)
		#expect(activationCount == 2)
	}

	@Test
	func relaunchIsPostponedUntilActiveLifecycleFinishes() {
		let lifecycle = makeLifecycleStore()
		lifecycle.activity = .runningGame(sessionID: UUID(), processIdentifier: 42)
		let subject = LauncherUpdaterController(lifecycle: lifecycle, log: lifecycle.log)
		let sparkle = makeSparkleUpdater()
		var installCalled = false

		#expect(
			subject.updater(
				sparkle.1,
				shouldPostponeRelaunchForUpdate: .empty(),
				untilInvokingBlock: { installCalled = true }
			)
		)
		lifecycle.activity = .idle

		#expect(installCalled)
	}

	@Test
	func terminationRetryResumesWhenLifecycleBecomesIdle() {
		let lifecycle = makeLifecycleStore()
		lifecycle.activity = .runningGame(sessionID: UUID(), processIdentifier: 42)
		let subject = LauncherUpdaterController(lifecycle: lifecycle, log: lifecycle.log)
		var retryCount = 0

		subject.userDriver.showInstallingUpdate(withApplicationTerminated: false) {
			retryCount += 1
		}
		#expect(retryCount == 0)

		lifecycle.activity = .idle

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
	func abortAfterSparkleErrorAcknowledgementDoesNotReopenTheError() {
		let subject = makeUpdater()
		let sparkle = makeSparkleUpdater()
		subject.userDriver.showUpdaterError(
			NSError(domain: "Test", code: 1), acknowledgement: {}
		)
		subject.userDriver.acknowledge()

		subject.updater(
			sparkle.1,
			didAbortWithError: NSError(domain: "Test", code: 1)
		)

		#expect(subject.userDriver.phase == .hidden)
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
	}

	@Test
	func abortingSilentProbeCompletesWhenTheCycleFinishes() {
		let subject = makeUpdater()
		var outcome: LauncherUpdateCheckOutcome?
		subject.beginProbeForTesting { outcome = $0 }
		subject.updater(
			makeSparkleUpdater().1,
			didAbortWithError: NSError(domain: "Test", code: 1)
		)

		#expect(outcome == nil)
		subject.updater(
			makeSparkleUpdater().1,
			didFinishUpdateCycleFor: .updateInformation,
			error: NSError(domain: "Test", code: 1)
		)
		#expect(outcome == .failed)
	}

	@Test
	func silentNoUpdateAbortThenFinishStaysHiddenAndCurrent() {
		let subject = makeUpdater()
		var outcome: LauncherUpdateCheckOutcome?
		subject.beginProbeForTesting { outcome = $0 }
		let error = NSError(
			domain: SUSparkleErrorDomain,
			code: Int(SUError.noUpdateError.rawValue),
			userInfo: [NSLocalizedDescriptionKey: "You’re up to date!"]
		)

		subject.updater(makeSparkleUpdater().1, didAbortWithError: error)
		#expect(outcome == nil)
		#expect(subject.userDriver.phase == .hidden)

		subject.updater(
			makeSparkleUpdater().1,
			didFinishUpdateCycleFor: .updateInformation,
			error: error
		)

		#expect(outcome == .current)
		#expect(subject.userDriver.phase == .hidden)

		subject.userDriver.showUserInitiatedUpdateCheck(cancellation: {})
		subject.updater(
			makeSparkleUpdater().1,
			didFinishUpdateCycleFor: .updateInformation,
			error: nil
		)
		#expect(subject.userDriver.phase == .hidden)
	}

	@Test
	func silentProbeAbortThenFinishDoesNotPresentOtherErrors() {
		let subject = makeUpdater()
		var outcome: LauncherUpdateCheckOutcome?
		subject.beginProbeForTesting { outcome = $0 }
		let error = NSError(domain: "Test", code: 1)

		subject.updater(makeSparkleUpdater().1, didAbortWithError: error)
		subject.updater(
			makeSparkleUpdater().1,
			didFinishUpdateCycleFor: .updateInformation,
			error: error
		)

		#expect(outcome == .failed)
		#expect(subject.userDriver.phase == .hidden)
	}

	@Test
	func finishingProbeCanStartTheNextProbeWithoutOldFinishInterference() {
		let subject = makeUpdater()
		var completionCount = 0
		subject.beginProbeForTesting { _ in
			completionCount += 1
			subject.beginProbeForTesting { _ in completionCount += 10 }
		}
		let error = NSError(domain: "Test", code: 1)

		subject.updater(makeSparkleUpdater().1, didAbortWithError: error)
		#expect(completionCount == 0)
		subject.updater(
			makeSparkleUpdater().1,
			didFinishUpdateCycleFor: .updateInformation,
			error: error
		)

		#expect(completionCount == 1)
		subject.updater(makeSparkleUpdater().1, didAbortWithError: error)
		subject.updater(
			makeSparkleUpdater().1,
			didFinishUpdateCycleFor: .updateInformation,
			error: error
		)
		#expect(completionCount == 11)
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
