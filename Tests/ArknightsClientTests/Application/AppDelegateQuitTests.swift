// SPDX-License-Identifier: MPL-2.0

import AppKit
import Sparkle
import Testing

@testable import ArknightsClient

@MainActor
struct AppDelegateQuitTests {
	@Test(arguments: UpdateQuitPath.allCases)
	func installingUpdateTerminationUsesTheQuitHandler(path: UpdateQuitPath) {
		let fixture = QuitFixture()
		fixture.prepareUpdateInstallation()
		#expect(fixture.updater.userDriver.phase == .readyToInstall)

		switch path {
		case .quitEvent:
			fixture.sendQuitEvent()
		case .manualRetry:
			fixture.updater.userDriver.showInstallingUpdate(
				withApplicationTerminated: false
			) { [weak fixture] in
				fixture?.sendQuitEvent()
			}
			fixture.updater.userDriver.retryTerminationRequest()
		}

		#expect(fixture.terminationCount == 1)
	}

	@Test(arguments: NonInstallingUpdateState.allCases)
	func nonInstallingUpdateStatesDoNotAuthorizeTermination(
		state: NonInstallingUpdateState
	) {
		let fixture = QuitFixture()
		switch state {
		case .downloadPrompt:
			fixture.lifecycle.beginLauncherUpdate()
			fixture.updater.userDriver.showDownloadInitiated(cancellation: {})
		case .readyPrompt:
			fixture.lifecycle.beginLauncherUpdate()
			fixture.updater.userDriver.showReady(toInstallAndRelaunch: { _ in })
		case .updaterError:
			fixture.prepareUpdateInstallation()
			fixture.updater.userDriver.showUpdaterError(
				NSError(domain: "Test", code: 1), acknowledgement: {})
		case .cancelledDownload:
			fixture.prepareUpdateInstallation()
			fixture.updater.userDidCancelDownload(fixture.sparkle)
		case .abortedUpdate:
			fixture.prepareUpdateInstallation()
			fixture.updater.updater(
				fixture.sparkle, didAbortWithError: NSError(domain: "Test", code: 1))
		}

		fixture.sendQuitEvent()

		#expect(fixture.terminationCount == 0)
		if state == .cancelledDownload || state == .abortedUpdate {
			#expect(fixture.updater.installationID == nil)
		}

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
	@Test(arguments: QuitRevalidationScenario.allCases)
	func sheetDismissalRevalidatesTheQuitRequest(scenario: QuitRevalidationScenario) {
		let fixture = QuitFixture()
		fixture.prepareUpdateInstallation()
		let installationID = fixture.updater.installationID
		var replacementInstallationID: UUID?
		var stoppingActivity: LauncherActivity?
		switch scenario {
		case .activityBecameBusy:
			fixture.delegate.dismissPresentationForQuit = { [weak fixture] in
				let activity = LauncherActivity.stoppingGame(
					sessionID: UUID(), processIdentifier: 42)
				stoppingActivity = activity
				fixture?.lifecycle.activity = activity
			}
		case .updateWasReplaced:
			fixture.delegate.dismissPresentationForQuit = { [weak fixture] in
				guard let fixture else { return }
				fixture.updater.userDidCancelDownload(fixture.sparkle)
				fixture.prepareUpdateInstallation()
				replacementInstallationID = fixture.updater.installationID
			}
		case .installationWasRepeated:
			fixture.delegate.dismissPresentationForQuit = { [weak fixture] in
				fixture?.prepareUpdateInstallation()
			}
		}

		fixture.sendQuitEvent()

		#expect(fixture.terminationCount == (scenario == .installationWasRepeated ? 1 : 0))
		switch scenario {
		case .activityBecameBusy:
			#expect(fixture.lifecycle.activity == stoppingActivity)
		case .updateWasReplaced:
			#expect(replacementInstallationID != nil)
			#expect(fixture.updater.installationID == replacementInstallationID)
		case .installationWasRepeated:
			#expect(fixture.updater.installationID == installationID)
		}
	}

	@Test(arguments: [
		("no prompt", nil as LauncherPresentationDestination?, false),
		("settings", .settings, true),
		("popup", .popup, true),
		(
			"failure",
			.failure(
				LauncherFailurePresentation(
					id: UUID(), message: "Failed", code: nil,
					context: SupportContext(operation: .launch, region: nil),
					actions: [.reportProblem]
				)
			),
			true
		),
	])
	func ordinaryQuitClosesPromptsAndTerminates(
		_ scenarioName: String,
		destination: LauncherPresentationDestination?,
		expectedDismissal: Bool
	) {
		let fixture = QuitFixture()
		fixture.delegate.blockingPresentationForQuit = { destination }
		var dismissed = false
		fixture.delegate.dismissPresentationForQuit = { dismissed = true }

		fixture.sendQuitEvent()

		#expect(fixture.terminationCount == 1)
		#expect(dismissed == expectedDismissal)
	}

	@Test
	func ordinaryQuitLeavesTheSparklePromptInControl() {
		let fixture = QuitFixture()
		fixture.delegate.blockingPresentationForQuit = { .update }

		fixture.sendQuitEvent()

		#expect(fixture.terminationCount == 0)
	}

	@Test
	func systemLogoutIsNeverVetoedByLauncherPrompts() {
		let fixture = QuitFixture()
		fixture.lifecycle.beginLauncherUpdate()
		fixture.updater.userDriver.showDownloadInitiated(cancellation: {})
		fixture.delegate.blockingPresentationForQuit = { .update }

		fixture.sendQuitEvent(reason: AEKeyword(kAELogOut))

		#expect(fixture.terminationCount == 1)
	}
}

enum UpdateQuitPath: String, CaseIterable, Sendable {
	case quitEvent
	case manualRetry
}

enum NonInstallingUpdateState: String, CaseIterable, Equatable, Sendable {
	case downloadPrompt
	case readyPrompt
	case updaterError
	case cancelledDownload
	case abortedUpdate
}

enum QuitRevalidationScenario: String, CaseIterable, Equatable, Sendable {
	case activityBecameBusy
	case updateWasReplaced
	case installationWasRepeated
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

	func sendQuitEvent(reason: AEKeyword? = nil) {
		let event = NSAppleEventDescriptor(
			eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEQuitApplication),
			targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
			transactionID: AETransactionID(kAnyTransactionID))
		if let reason {
			event.setAttribute(
				NSAppleEventDescriptor(enumCode: OSType(reason)),
				forKeyword: AEKeyword(kAEQuitReason))
		}
		delegate.perform(
			NSSelectorFromString("handleQuitEvent:withReplyEvent:"),
			with: event, with: NSAppleEventDescriptor())
	}
}
