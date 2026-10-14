// SPDX-License-Identifier: MPL-2.0

import Foundation
import Sparkle
import Testing

@testable import ArknightsLauncherUI

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

		// Dismissing the overlay cancels an active check at once.
		driver.showUserInitiatedUpdateCheck { cancellationCount += 1 }
		driver.dismissFromUser()
		#expect(cancellationCount == 2)
		#expect(driver.phase == .hidden)

		// A replacement callback takes over the stale check cancellation.
		var replacementCancellations = 0
		var acknowledgements = 0
		driver.showUserInitiatedUpdateCheck { replacementCancellations += 1 }
		driver.showUpdateNotFoundWithError(
			NSError(domain: "Test", code: 1), acknowledgement: { acknowledgements += 1 })
		driver.dismissFromUser()
		driver.cancelCheck()
		#expect(replacementCancellations == 0)
		#expect(acknowledgements == 1)
		#expect(driver.phase == .hidden)
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

		var dismissed: [SPUUserUpdateChoice] = []
		driver.showReady { dismissed.append($0) }
		driver.dismissFromUser()
		#expect(dismissed == [.dismiss])
		#expect(driver.phase == .hidden)

		var relaunchAcknowledgements = 0
		driver.showUpdateInstalledAndRelaunched(true) { relaunchAcknowledgements += 1 }
		#expect(relaunchAcknowledgements == 1)
		#expect(driver.phase == .hidden)
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

		// Ending the installation cancels a pending automatic retry.
		var safeToRetry = false
		var endedRetryCount = 0
		var pendingRetry: (@MainActor () -> Void)?
		let waiting = LauncherUpdateUserDriver(
			canRetryTermination: { safeToRetry },
			automaticRetryScheduler: { action in
				pendingRetry = action
				return Task { @MainActor in }
			}
		)
		waiting.showInstallingUpdate(withApplicationTerminated: false) { endedRetryCount += 1 }
		safeToRetry = true
		waiting.dismissUpdateInstallation()
		pendingRetry?()
		waiting.retryTerminationIfSafe()
		#expect(endedRetryCount == 0)

		// The retry waits for a safe transition.
		safeToRetry = false
		var transitionRetryCount = 0
		let transition = LauncherUpdateUserDriver(
			canRetryTermination: { safeToRetry },
			automaticRetryScheduler: { _ in Task { @MainActor in } }
		)
		transition.showInstallingUpdate(withApplicationTerminated: false) {
			transitionRetryCount += 1
		}
		#expect(transitionRetryCount == 0)
		safeToRetry = true
		transition.retryTerminationIfSafe()
		#expect(transitionRetryCount == 1)
	}
}
