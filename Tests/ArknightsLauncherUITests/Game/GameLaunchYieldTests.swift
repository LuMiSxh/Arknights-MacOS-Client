// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime
@testable import ArknightsLauncherUI

@MainActor
struct GameLaunchYieldTests {
	@Test(.timeLimit(.minutes(1)))
	func launchCancelsGameEnvironmentMaintenanceThenClaimsTheLauncher() async throws {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let lifecycle = model.lifecycle
		let lease = try #require(lifecycle.begin(.maintaining(.updatingGameEnvironments)))
		let yielded = Signal()
		model.gameSession.yieldMaintenanceToLaunch = {
			lifecycle.end(lease)
			yielded.fire()
		}

		model.gameSession.launch()
		await yielded.wait()
		// The launch ran past the yield: with no game installed it reports that and ends.
		await waitForCondition { lifecycle.state.presentation.failure != nil }

		#expect(lifecycle.activity == .idle)
		await api.resolveBranding()
	}

	@Test(.timeLimit(.minutes(1)))
	func launchDoesNotInterruptOtherMaintenance() async throws {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		var yielded = false
		model.gameSession.yieldMaintenanceToLaunch = { yielded = true }
		_ = try #require(model.lifecycle.begin(.maintaining(.clearingCache)))

		model.gameSession.launch()

		#expect(!yielded)
		#expect(!model.gameSession.isLaunchPendingOrActive)
		await api.resolveBranding()
	}
}
