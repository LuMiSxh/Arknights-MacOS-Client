// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

@MainActor
struct RecoveryActionTests {
	@Test(arguments: SupportCode.allCases)
	func retryAndRepairFollowTheCatalogFlags(code: SupportCode) {
		let actions = LauncherLifecycleStore.recoveryActions(for: code, canRepair: true)
		#expect(actions.contains(.retry) == code.allowsRetry)
		#expect(actions.contains(.repair) == code.allowsRepair)
	}
}
