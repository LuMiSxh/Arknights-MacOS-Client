// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

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
			LauncherError.runtimeExited(
				status: 1,
				log: model.installation.paths.logFile
			),
			id: failureID,
			operation: .runtimeExit,
			region: region
		)
		#expect(model.lifecycle.failure?.context.region == region.supportRegion)
		#expect(model.lifecycle.failure?.blocksGameLaunch == false)

		#expect(model.gameSession.retryRuntimeFailure(id: failureID))
		#expect(!model.gameSession.retryRuntimeFailure(id: failureID))
		#expect(model.lifecycle.failure?.code == .pebble)
		#expect(model.lifecycle.failure?.context.operation == .launch)
		#expect(model.lifecycle.failure?.context.region == region.supportRegion)
		#expect(model.lifecycle.failure?.blocksGameLaunch == true)
		await api.resolveBranding()
	}

	@Test
	func stopRetryKeepsTheRunningSessionAndUsesRuntimeStopContext() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let sessionID = UUID()
		model.lifecycle.activity = .runningGame(
			sessionID: sessionID,
			processIdentifier: 42
		)
		model.gameSession.presentRuntimeFailure(
			LauncherError.runtimeConfiguration("test"),
			id: sessionID,
			operation: .runtimeStop,
			region: .global
		)
		#expect(model.lifecycle.failure?.blocksGameLaunch == false)

		#expect(model.gameSession.retryRuntimeFailure(id: sessionID))
		#expect(
			model.lifecycle.activity
				== .runningGame(sessionID: sessionID, processIdentifier: 42)
		)
		#expect(model.lifecycle.failure?.code == .whelk)
		#expect(model.lifecycle.failure?.context.operation == .runtimeStop)
		#expect(!model.gameSession.retryRuntimeFailure(id: UUID()))
		await api.resolveBranding()
	}
}
