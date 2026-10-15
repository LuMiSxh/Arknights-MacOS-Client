// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsLauncherUI

@MainActor
struct LauncherACEWarningTests {
	@Test
	func firstACEClientLaunchRequiresConfirmationAndRecordsAcknowledgement() async {
		for (region, acknowledged, expected) in [
			(GameRegion.china, false, true),
			(.chinaBilibili, false, true),
			(.taiwan, false, true),
			(.china, true, false),
			(.global, false, false),
			(.japan, false, false),
		] {
			#expect(
				LauncherViewModel.shouldPresentACEWarning(for: region, acknowledged: acknowledged)
					== expected)
		}
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		model.installation.region = .china

		model.actions.launch()

		#expect(model.pendingACEWarningRegion == .china)
		#expect(!model.preferences.hasAcknowledgedACEWarning(for: .china))

		model.actions.confirmACEWarningAndLaunch()

		#expect(model.pendingACEWarningRegion == nil)
		#expect(model.preferences.hasAcknowledgedACEWarning(for: .china))
		model.refreshController.cancelRefresh()
		await api.resolveBranding()
	}
}
