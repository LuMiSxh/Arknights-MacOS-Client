// SPDX-License-Identifier: MPL-2.0

import Foundation
import Sparkle
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherUpdateUserDriverTests {
	@Test
	func checkCancellationIsDeliveredOnceAndDismissesThePresentation() {
		let driver = LauncherUpdateUserDriver()
		var cancellationCount = 0
		driver.showUserInitiatedUpdateCheck { cancellationCount += 1 }

		driver.cancelCheck()
		driver.cancelCheck()

		#expect(cancellationCount == 1)
		#expect(driver.phase == .hidden)
	}

	@Test
	func downloadAndExtractionProgressAreClampedAndPreserveStages() {
		let driver = LauncherUpdateUserDriver()
		driver.showDownloadInitiated(cancellation: {})
		driver.showDownloadDidReceiveExpectedContentLength(100)
		driver.showDownloadDidReceiveData(ofLength: 140)

		#expect(driver.phase == .downloading)
		#expect(driver.receivedBytes == 140)

		driver.showDownloadDidStartExtractingUpdate()
		driver.showExtractionReceivedProgress(1.4)

		#expect(driver.phase == .extracting)
		#expect(driver.extractionProgress == 1)
	}

	@Test
	func updateReplyIsDeliveredOnceAndDismissChoiceIsSupported() {
		let driver = LauncherUpdateUserDriver()
		var choices: [SPUUserUpdateChoice] = []
		driver.showReady { choices.append($0) }

		driver.choose(.install)
		driver.choose(.dismiss)

		#expect(choices == [.install])
		#expect(driver.phase == .readyToInstall)
		#expect(driver.isPresented)
		driver.dismissUpdateInstallation()
	}

	@Test
	func installChoiceKeepsOnePresentationAcrossDownloadStages() {
		let driver = LauncherUpdateUserDriver()
		var choices: [SPUUserUpdateChoice] = []
		driver.showReady { choices.append($0) }

		driver.choose(.install)
		driver.showDownloadInitiated(cancellation: {})
		driver.showDownloadDidStartExtractingUpdate()
		driver.showReady { choices.append($0) }

		#expect(choices == [.install])
		#expect(driver.phase == .readyToInstall)
		#expect(driver.isPresented)
		driver.dismissUpdateInstallation()
	}

	@Test
	func dismissFromUserWhenReadyToInstallRepliesTheSameAsLater() {
		let driver = LauncherUpdateUserDriver()
		var choices: [SPUUserUpdateChoice] = []
		driver.showReady { choices.append($0) }

		driver.dismissFromUser()

		#expect(choices == [.dismiss])
		#expect(driver.phase == .hidden)
		#expect(!driver.isPresented)
	}

	@Test
	func errorAcknowledgementClearsTheCustomPresentation() {
		let driver = LauncherUpdateUserDriver()
		var acknowledgementCount = 0
		driver.showUpdaterError(
			NSError(domain: "Test", code: 1),
			acknowledgement: { acknowledgementCount += 1 }
		)

		driver.acknowledge()
		driver.acknowledge()

		#expect(acknowledgementCount == 1)
		#expect(driver.phase == .hidden)
	}

	@Test
	func noUpdateAcknowledgementReplacesStaleCheckCancellation() {
		let driver = LauncherUpdateUserDriver()
		var cancellationCount = 0
		var acknowledgementCount = 0
		driver.showUserInitiatedUpdateCheck { cancellationCount += 1 }
		driver.showUpdateNotFoundWithError(
			NSError(domain: "Test", code: 1),
			acknowledgement: { acknowledgementCount += 1 }
		)

		driver.dismissFromUser()
		driver.cancelCheck()

		#expect(cancellationCount == 0)
		#expect(acknowledgementCount == 1)
		#expect(driver.phase == .hidden)
	}

	@Test
	func updaterErrorAcknowledgementReplacesStaleCallbacks() {
		let driver = LauncherUpdateUserDriver()
		var cancellationCount = 0
		var acknowledgementCount = 0
		driver.showUserInitiatedUpdateCheck { cancellationCount += 1 }
		driver.showUpdaterError(
			NSError(domain: "Test", code: 1),
			acknowledgement: { acknowledgementCount += 1 }
		)

		driver.dismissFromUser()
		driver.acknowledge()

		#expect(cancellationCount == 0)
		#expect(acknowledgementCount == 1)
		#expect(driver.phase == .hidden)
	}

	@Test
	func relaunchedInstallationAcknowledgesImmediately() {
		let driver = LauncherUpdateUserDriver()
		var acknowledgementCount = 0
		driver.showUpdateInstalledAndRelaunched(true) { acknowledgementCount += 1 }

		#expect(acknowledgementCount == 1)
		#expect(driver.phase == .hidden)
		driver.acknowledge()
		#expect(acknowledgementCount == 1)
	}

	@Test
	func updateInFocusKeepsTheCurrentPresentationVisible() {
		var activationCount = 0
		let driver = LauncherUpdateUserDriver { activationCount += 1 }
		driver.showUserInitiatedUpdateCheck(cancellation: {})

		driver.showUpdateInFocus()

		#expect(activationCount == 1)
		#expect(driver.isPresented)
	}

	@Test
	func installingDismissalHidesAndFocusRestoresTheSamePresentation() {
		var activationCount = 0
		var retryCount = 0
		let driver = LauncherUpdateUserDriver(
			activateApplication: { activationCount += 1 },
			canRetryTermination: { false }
		)
		driver.showInstallingUpdate(withApplicationTerminated: false) { retryCount += 1 }

		driver.dismissFromUser()

		#expect(!driver.isPresented)
		#expect(driver.phase == .installing)
		driver.showUpdateInFocus()
		driver.retryTerminationRequest()

		#expect(driver.isPresented)
		#expect(activationCount == 1)
		#expect(retryCount == 1)
	}

	@Test
	func automaticTerminationRetryRunsOnceWhenSafeAndManualRetryRemainsAvailable() {
		var retryCount = 0
		var runAutomaticRetry: (@MainActor () -> Void)?
		let driver = LauncherUpdateUserDriver(
			canRetryTermination: { true },
			automaticRetryScheduler: { action in
				runAutomaticRetry = action
				return Task { @MainActor in }
			}
		)
		driver.showInstallingUpdate(withApplicationTerminated: false) { retryCount += 1 }
		#expect(retryCount == 0)
		runAutomaticRetry?()

		#expect(retryCount == 1)
		driver.retryTerminationIfSafe()
		driver.retryTerminationRequest()

		#expect(retryCount == 2)
	}

	@Test
	func automaticTerminationRetryWaitsForSafeTransition() {
		var safeToRetry = false
		var retryCount = 0
		let driver = LauncherUpdateUserDriver(
			canRetryTermination: { safeToRetry },
			automaticRetryScheduler: { _ in Task { @MainActor in } }
		)
		driver.showInstallingUpdate(withApplicationTerminated: false) { retryCount += 1 }
		#expect(retryCount == 0)

		safeToRetry = true
		driver.retryTerminationIfSafe()

		#expect(retryCount == 1)
	}

	@Test
	func terminationContextDistinguishesGameFromOtherBusyActivity() {
		var gameRunning = true
		var safeToRetry = false
		var retryCount = 0
		let driver = LauncherUpdateUserDriver(
			canRetryTermination: { safeToRetry },
			isGameRunning: { gameRunning },
			automaticRetryScheduler: { _ in Task { @MainActor in } }
		)
		driver.showInstallingUpdate(withApplicationTerminated: false) { retryCount += 1 }

		#expect(driver.gameIsRunning)
		#expect(!driver.terminationBlocked)
		gameRunning = false
		driver.retryTerminationIfSafe()

		#expect(!driver.gameIsRunning)
		#expect(driver.terminationBlocked)
		safeToRetry = true
		driver.retryTerminationIfSafe()

		#expect(!driver.terminationBlocked)
		#expect(retryCount == 1)
	}

	@Test
	func endingInstallationCancelsPendingAutomaticRetry() {
		var safeToRetry = false
		var retryCount = 0
		var runAutomaticRetry: (@MainActor () -> Void)?
		let driver = LauncherUpdateUserDriver(
			canRetryTermination: { safeToRetry },
			automaticRetryScheduler: { action in
				runAutomaticRetry = action
				return Task { @MainActor in }
			}
		)
		driver.showInstallingUpdate(withApplicationTerminated: false) { retryCount += 1 }
		driver.dismissUpdateInstallation()
		safeToRetry = true
		runAutomaticRetry?()
		driver.retryTerminationIfSafe()

		#expect(retryCount == 0)
	}

	@Test
	func directErrorPresentationCanBeDismissedWithoutSparkleAcknowledgement() {
		let driver = LauncherUpdateUserDriver()
		driver.showError(NSError(domain: "Test", code: 1))

		driver.acknowledge()

		#expect(driver.phase == .hidden)
	}
}
