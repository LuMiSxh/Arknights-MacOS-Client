// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import Sparkle
import Testing

@testable import ArknightsClient
@testable import ArknightsLauncherUI

@MainActor
struct AppDelegateQuitTests {
	@Test(arguments: QuitScenario.allCases)
	func installingUpdateTerminationUsesTheQuitHandler(scenario: QuitScenario) {
		let fixture = QuitFixture()
		var dismissed = false
		fixture.delegate.dismissPresentationForQuit = { dismissed = true }
		switch scenario {
		case .quitEvent:
			fixture.prepareUpdateInstallation()
		case .manualRetry:
			fixture.prepareUpdateInstallation()
			fixture.updater.userDriver.showInstallingUpdate(
				withApplicationTerminated: false
			) { [weak fixture] in
				fixture?.sendQuitEvent()
			}
			fixture.updater.userDriver.retryTerminationRequest()
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
		case .ordinaryQuitWithOpenSettings:
			fixture.delegate.blockingPresentationForQuit = { .settings }
		case .ordinaryQuitWithoutPrompt:
			fixture.delegate.blockingPresentationForQuit = { nil }
		case .ordinaryQuitDuringSparklePrompt:
			fixture.delegate.blockingPresentationForQuit = { .update }
		}

		if scenario != .manualRetry { fixture.sendQuitEvent() }

		#expect(fixture.terminationCount == (scenario.terminates ? 1 : 0))
		if scenario == .cancelledDownload || scenario == .abortedUpdate {
			#expect(fixture.updater.installationID == nil)
		}
		if scenario == .ordinaryQuitWithOpenSettings { #expect(dismissed) }
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
		fixture.lifecycle.simulateActivity(activity)
		// The lifecycle gate must also hold when the update presentation is hidden.
		fixture.delegate.blockingPresentationForQuit = { nil }
		fixture.updater.userDriver.showInstallingUpdate(withApplicationTerminated: false) {
			[weak fixture] in
			fixture?.sendQuitEvent()
		}

		fixture.sendQuitEvent()
		fixture.updater.userDriver.retryTerminationRequest()
		#expect(fixture.terminationCount == 0)

		fixture.lifecycle.simulateActivity(.idle)

		#expect(fixture.terminationCount == 1)
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

enum QuitScenario: String, CaseIterable, Equatable, Sendable {
	case quitEvent
	case manualRetry
	case downloadPrompt
	case readyPrompt
	case updaterError
	case cancelledDownload
	case abortedUpdate
	case ordinaryQuitWithOpenSettings
	case ordinaryQuitWithoutPrompt
	case ordinaryQuitDuringSparklePrompt

	var terminates: Bool {
		switch self {
		case .quitEvent, .manualRetry, .ordinaryQuitWithOpenSettings, .ordinaryQuitWithoutPrompt:
			true
		default:
			false
		}
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
