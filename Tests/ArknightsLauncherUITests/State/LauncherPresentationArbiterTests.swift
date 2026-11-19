// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsLauncherUI

@MainActor
@Test
func aSameFailureUpdateReplacesThePresentedValue() {
	var arbiter = LauncherPresentationArbiter()
	let id = UUID()
	let failure = LauncherFailurePresentation(
		id: id,
		message: "Waiting",
		code: nil,
		context: SupportContext(operation: .launcher, region: nil),
		actions: [.quit],
		blocksGameLaunch: true,
		showsDismissAction: false
	)
	let busy = LauncherFailurePresentation(
		id: id,
		message: "Deleting…",
		code: nil,
		context: failure.context,
		actions: failure.actions,
		blocksGameLaunch: true,
		showsDismissAction: false,
		isBusy: true
	)

	arbiter.request(.failure(failure))
	arbiter.request(.failure(busy))

	#expect(arbiter.current == .failure(busy))
}
