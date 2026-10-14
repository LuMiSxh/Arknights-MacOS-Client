// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsLauncherUI

@MainActor
struct LauncherMetadataRefreshCancellationTests {
	@Test
	func installationCancellationInvalidatesMetadataBeforeTheTaskCanResume() async {
		let api = CancellableBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		model.refreshController.cancelRefresh()
		let task = model.refreshController.startRefresh()
		#expect(model.lifecycle.state.refresh.requestID != nil)

		model.refreshController.cancelForInstallationStart()
		#expect(model.lifecycle.state.refresh == .idle)
		await task.value
		#expect(model.lifecycle.state.refresh == .idle)
	}
}
