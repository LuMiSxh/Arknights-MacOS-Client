// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsLauncherUI

@MainActor
@Test
func pendingPopupBlocksApplicationQuit() {
	let arbiter = LauncherPresentationArbiter()

	#expect(arbiter.blockingDestination(hasPendingPopup: true) == .popup)
}
