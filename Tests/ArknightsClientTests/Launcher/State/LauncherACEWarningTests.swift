// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherACEWarningTests {
	@Test(arguments: [
		(GameRegion.china, false, true),
		(GameRegion.chinaBilibili, false, true),
		(GameRegion.taiwan, false, true),
		(GameRegion.china, true, false),
		(GameRegion.global, false, false),
		(GameRegion.japan, false, false),
	])
	func launchWarningPolicyIsLimitedToUnacknowledgedACEClients(
		region: GameRegion,
		acknowledged: Bool,
		expected: Bool
	) {
		#expect(
			LauncherViewModel.shouldPresentACEWarning(
				for: region,
				acknowledged: acknowledged
			) == expected
		)
	}

	@Test
	func firstACEClientLaunchRequiresConfirmationAndRecordsAcknowledgement() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		model.installation.region = .china

		model.launch()

		#expect(model.pendingACEWarningRegion == .china)
		#expect(!model.preferences.hasAcknowledgedACEWarning(for: .china))

		model.confirmACEWarningAndLaunch()

		#expect(model.pendingACEWarningRegion == nil)
		#expect(model.preferences.hasAcknowledgedACEWarning(for: .china))
		model.refreshController.cancelRefresh()
		await api.resolveBranding()
	}
}
