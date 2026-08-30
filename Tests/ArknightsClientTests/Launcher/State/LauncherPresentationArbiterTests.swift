// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func presentationArbiterQueuesAndPromotesHigherPriorityDestinations() {
	var arbiter = LauncherPresentationArbiter()
	let failure = LauncherFailurePresentation(
		id: UUID(),
		message: "failure",
		code: nil,
		context: SupportContext(operation: .launcher, region: nil),
		actions: [.reportProblem]
	)

	arbiter.request(.settings)
	arbiter.request(.failure(failure))

	#expect(arbiter.current == nil)
	#expect(arbiter.queued == .failure(failure))
	arbiter.didDismiss()
	#expect(arbiter.current == .failure(failure))
	#expect(arbiter.queued == nil)
	// A second modal remains queued until the current sheet is dismissed.
	arbiter.dismissCurrent()
	arbiter.request(.settings)
	arbiter.request(.update)

	#expect(arbiter.current == nil)
	#expect(arbiter.queued == .update)
	arbiter.didDismiss()
	#expect(arbiter.current == .update)
}
