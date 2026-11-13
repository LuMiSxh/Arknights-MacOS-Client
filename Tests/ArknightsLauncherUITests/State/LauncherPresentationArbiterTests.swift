// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsLauncherUI

@MainActor
@Test
func pendingPopupBlocksApplicationQuit() {
	let arbiter = LauncherPresentationArbiter()

	#expect(arbiter.blockingDestination(hasPendingPopup: true) == .popup)
}

private func makeFailure() -> LauncherFailurePresentation {
	LauncherFailurePresentation(
		id: UUID(),
		message: "Test failure",
		code: nil,
		context: SupportContext(operation: .launcher, region: nil),
		actions: [.reportProblem]
	)
}

@MainActor
@Test(arguments: [SupportOperation.install, .update, .runtimeSetup])
func setupFailureWaitsForSetupAndPresentsOnceItCloses(operation: SupportOperation) {
	let failure = LauncherFailurePresentation(
		id: UUID(),
		message: "Download failed",
		code: nil,
		context: SupportContext(operation: operation, region: nil),
		actions: [.reportProblem]
	)
	var arbiter = LauncherPresentationArbiter()

	#expect(arbiter.suppressesFailure(failure, isOnboardingPresented: true))
	#expect(arbiter.current == nil)

	// What ContentView does when setup closes.
	#expect(!arbiter.suppressesFailure(failure, isOnboardingPresented: false))
	arbiter.request(.failure(failure))
	#expect(arbiter.current == .failure(failure))

	// A failure outside setup keeps its presentation while setup is visible.
	#expect(!arbiter.suppressesFailure(makeFailure(), isOnboardingPresented: true))
	#expect(!arbiter.suppressesFailure(nil, isOnboardingPresented: true))
}

@MainActor
@Test
func settingsSheetIsDismissedBeforeAFailureIsPromoted() {
	var arbiter = LauncherPresentationArbiter()
	let failure = makeFailure()

	arbiter.request(.settings)
	arbiter.request(.failure(failure))
	#expect(arbiter.current == nil)
	#expect(arbiter.queued == .failure(failure))
	#expect(arbiter.presents(.failure(failure)))

	arbiter.didDismiss()
	#expect(arbiter.current == .failure(failure))
	#expect(arbiter.queued == nil)

	arbiter.dismissCurrent()
	#expect(arbiter.current == nil)
	#expect(arbiter.queued == nil)
	#expect(!arbiter.presents(.failure(failure)))
}

@MainActor
@Test
func presentedFailureKeepsItsIdentityAcrossTheSheetSwap() throws {
	let storage = try TemporaryDirectory("LauncherPresentationArbiterTests")
	defer { storage.remove() }
	let log = LauncherLog(fileURL: storage.url.appending(path: "launcher.log"))
	let lifecycle = LauncherLifecycleStore(log: log)
	let failure = makeFailure()
	lifecycle.presentFailure(failure, diagnostic: "test")

	var arbiter = LauncherPresentationArbiter()
	arbiter.request(.settings)
	arbiter.request(.failure(failure))
	arbiter.didDismiss()

	#expect(lifecycle.state.presentation.failure?.id == failure.id)
	#expect(arbiter.current == .failure(failure))
}

@MainActor
@Test
func restoringThePresentedFailureKeepsRecoveryActionsValid() throws {
	let storage = try TemporaryDirectory("LauncherPresentationArbiterTests")
	defer { storage.remove() }
	let log = LauncherLog(fileURL: storage.url.appending(path: "launcher.log"))
	let lifecycle = LauncherLifecycleStore(log: log)
	let failure = makeFailure()
	lifecycle.presentFailure(failure, diagnostic: "test")

	lifecycle.clearFailure()
	#expect(lifecycle.state.presentation.failure == nil)

	lifecycle.restoreFailure(failure)
	#expect(lifecycle.state.presentation.failure?.id == failure.id)
}
