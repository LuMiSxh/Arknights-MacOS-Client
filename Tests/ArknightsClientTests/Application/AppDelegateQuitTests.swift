// SPDX-License-Identifier: MPL-2.0

import AppKit
import Sparkle
import Testing

@testable import ArknightsClient

@MainActor
struct AppDelegateQuitTests {
	@Test
	func sparkleQuitBeforeInstallingPresentationTerminatesTheLauncher() {
		let fixture = QuitFixture()
		fixture.prepareUpdateInstallation()
		#expect(fixture.updater.userDriver.phase == .readyToInstall)
		fixture.sendQuitEvent()

		#expect(fixture.terminationCount == 1)
	}

	@Test
	func manualTerminationRetryUsesTheSameQuitHandler() {
		let fixture = QuitFixture()
		fixture.prepareUpdateInstallation()
		fixture.updater.userDriver.showInstallingUpdate(withApplicationTerminated: false) {
			[weak fixture] in
			fixture?.sendQuitEvent()
		}

		fixture.updater.userDriver.retryTerminationRequest()

		#expect(fixture.terminationCount == 1)
	}

	@Test(arguments: [false, true])
	func updateDownloadAndReadyPromptDoNotAuthorizeTermination(ready: Bool) {
		let fixture = QuitFixture()
		fixture.lifecycle.beginLauncherUpdate()
		if ready {
			fixture.updater.userDriver.showReady(toInstallAndRelaunch: { _ in })
		} else {
			fixture.updater.userDriver.showDownloadInitiated(cancellation: {})
		}

		fixture.sendQuitEvent()

		#expect(fixture.terminationCount == 0)
	}

	@Test(arguments: [
		LauncherActivity.installing(id: UUID(), stage: .downloading),
		.maintaining(.clearingCache),
		.preparingGame(sessionID: UUID()),
		.launchingGame(sessionID: UUID(), processIdentifier: nil),
		.runningGame(sessionID: UUID(), processIdentifier: 42),
		.stoppingGame(sessionID: UUID(), processIdentifier: 42),
	])
	func installationWaitsForTheEntireActiveOperation(activity: LauncherActivity) {
		let fixture = QuitFixture()
		fixture.prepareUpdateInstallation()
		fixture.lifecycle.activity = activity
		// The lifecycle gate must also hold when the update presentation is hidden.
		fixture.delegate.blockingPresentationForQuit = { nil }
		fixture.updater.userDriver.showInstallingUpdate(withApplicationTerminated: false) {
			[weak fixture] in
			fixture?.sendQuitEvent()
		}

		fixture.sendQuitEvent()
		fixture.updater.userDriver.retryTerminationRequest()
		#expect(fixture.terminationCount == 0)

		fixture.lifecycle.activity = .idle

		#expect(fixture.terminationCount == 1)
	}

	@Test
	func updaterErrorRevokesTerminationBeforeAcknowledgement() {
		let fixture = QuitFixture()
		fixture.prepareUpdateInstallation()
		fixture.updater.userDriver.showUpdaterError(
			NSError(domain: "Test", code: 1), acknowledgement: {})

		fixture.sendQuitEvent()

		#expect(fixture.terminationCount == 0)
	}

	@Test(arguments: [false, true])
	func endingAnUpdateRevokesItsTerminationPermission(aborted: Bool) {
		let fixture = QuitFixture()
		fixture.prepareUpdateInstallation()
		if aborted {
			fixture.updater.updater(
				fixture.sparkle, didAbortWithError: NSError(domain: "Test", code: 1))
		} else {
			fixture.updater.userDidCancelDownload(fixture.sparkle)
		}

		fixture.sendQuitEvent()

		#expect(fixture.terminationCount == 0)
		#expect(fixture.updater.installationID == nil)
	}

	@Test
	func sheetDismissalRevalidatesActivityBeforeTermination() {
		let fixture = QuitFixture()
		fixture.prepareUpdateInstallation()
		fixture.delegate.dismissSettingsForQuit = { [weak fixture] in
			fixture?.lifecycle.activity = .stoppingGame(sessionID: UUID(), processIdentifier: 42)
		}

		fixture.sendQuitEvent()

		#expect(fixture.terminationCount == 0)
	}

	@Test
	func sheetDismissalCannotTerminateAReplacementUpdate() {
		let fixture = QuitFixture()
		fixture.prepareUpdateInstallation()
		fixture.delegate.dismissSettingsForQuit = { [weak fixture] in
			guard let fixture else { return }
			fixture.updater.userDidCancelDownload(fixture.sparkle)
			fixture.prepareUpdateInstallation()
		}

		fixture.sendQuitEvent()

		#expect(fixture.terminationCount == 0)
	}

	@Test
	func repeatedInstallationNotificationKeepsTheCurrentQuitRequestValid() {
		let fixture = QuitFixture()
		fixture.prepareUpdateInstallation()
		fixture.delegate.dismissSettingsForQuit = { [weak fixture] in
			fixture?.prepareUpdateInstallation()
		}

		fixture.sendQuitEvent()

		#expect(fixture.terminationCount == 1)
	}

	@Test(arguments: [false, true])
	func ordinaryQuitStillClosesSettingsAndTerminates(settingsOpen: Bool) {
		let fixture = QuitFixture()
		fixture.delegate.blockingPresentationForQuit = { settingsOpen ? .settings : nil }
		var dismissed = false
		fixture.delegate.dismissSettingsForQuit = { dismissed = true }

		fixture.sendQuitEvent()

		#expect(fixture.terminationCount == 1)
		#expect(dismissed == settingsOpen)
	}

	@Test(arguments: [LauncherPresentationDestination.popup, .update])
	func ordinaryQuitPreservesActivePrompts(destination: LauncherPresentationDestination) {
		let fixture = QuitFixture()
		fixture.delegate.blockingPresentationForQuit = { destination }

		fixture.sendQuitEvent()

		#expect(fixture.terminationCount == 0)
	}
}

@MainActor
private final class QuitFixture {
	let lifecycle: LauncherLifecycleStore
	let updater: LauncherUpdaterController
	let sparkle: SPUUpdater
	let delegate = AppDelegate()
	var terminationCount = 0

	init() {
		_ = NSApplication.shared
		let logURL = FileManager.default.temporaryDirectory.appending(
			path: "AppDelegateQuitTests.\(UUID().uuidString).log")
		lifecycle = LauncherLifecycleStore(log: LauncherLog(fileURL: logURL))
		updater = LauncherUpdaterController(
			lifecycle: lifecycle, log: lifecycle.log, activateApplication: {})
		sparkle = SPUUpdater(
			hostBundle: .main, applicationBundle: .main,
			userDriver: updater.userDriver, delegate: updater)
		delegate.launcherUpdater = updater
		delegate.blockingPresentationForQuit = { .update }
		delegate.terminateApplication = { [weak self] in self?.terminationCount += 1 }
	}

	func prepareUpdateInstallation() {
		updater.userDriver.showReady(toInstallAndRelaunch: { _ in })
		updater.updater(sparkle, willInstallUpdate: .empty())
	}

	func sendQuitEvent() {
		let event = NSAppleEventDescriptor(
			eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEQuitApplication),
			targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
			transactionID: AETransactionID(kAnyTransactionID))
		delegate.perform(
			NSSelectorFromString("handleQuitEvent:withReplyEvent:"),
			with: event, with: NSAppleEventDescriptor())
	}
}
