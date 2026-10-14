// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation
@testable import ArknightsGameRuntime
@testable import ArknightsLauncherUI

@MainActor
struct GameSessionRecoveryTests {
	@Test(arguments: GameRegion.yostarCases)
	func runtimeRetryKeepsTheOriginalRegionAndRejectsDuplicates(
		region: GameRegion
	) async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		if region != .global {
			#expect(model.installation.selectRegion(region))
		}
		let failureID = UUID()
		model.gameSession.presentRuntimeFailure(
			GameRuntimeError.runtimeExited(
				status: 1,
				log: model.installation.paths.runtimeLogFile(for: region)
			),
			id: failureID,
			operation: .runtimeExit,
			region: region
		)
		#expect(model.lifecycle.state.presentation.failure?.context.region == region.supportRegion)
		#expect(model.lifecycle.state.presentation.failure?.blocksGameLaunch == false)

		#expect(model.gameSession.retryRuntimeFailure(id: failureID))
		#expect(!model.gameSession.retryRuntimeFailure(id: failureID))
		// The launch preflight is asynchronous, so the failure appears after the retry returns.
		#expect(await waitForCondition { model.lifecycle.state.presentation.failure != nil })
		#expect(model.lifecycle.state.presentation.failure?.code == .pebble)
		#expect(model.lifecycle.state.presentation.failure?.context.operation == .launch)
		#expect(model.lifecycle.state.presentation.failure?.context.region == region.supportRegion)
		#expect(model.lifecycle.state.presentation.failure?.blocksGameLaunch == true)
		await api.resolveBranding()
	}
}
