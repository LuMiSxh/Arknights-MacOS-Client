// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsLauncherUI

#if DEBUG
	@MainActor
	struct DeveloperSimulationRoutingTests {
		@Test
		func simulatedConfigurationRetryClearsFailureWithoutLaunching() async {
			let api = CancellableBrandingAPI()
			let model = makeModel(
				api: api,
				installer: ControllableInstaller(),
				arguments: ["--developer-preview"]
			)
			await api.waitForBrandingRequest()
			await api.resolveBranding()

			var simulation = model.developerSimulation!
			simulation.failure = .configuration
			model.applyDeveloperSimulation(simulation)
			let failureID = model.lifecycle.state.presentation.failure!.id

			#expect(model.performRecoveryAction(.retry, failureID: failureID) == .completed)
			#expect(model.developerSimulation?.failure == DeveloperSimulationState.Failure.none)
			#expect(model.developerSimulation?.lifecycle == .ready)
			#expect(!model.lifecycle.activity.isGameActive)
		}

		@Test
		func simulatedNonblockingFailuresAllowDockLaunch() async throws {
			let api = CancellableBrandingAPI()
			let model = makeModel(
				api: api, installer: ControllableInstaller(), arguments: ["--developer-preview"])
			await api.waitForBrandingRequest()
			await api.resolveBranding()

			for kind in [DeveloperSimulationState.Failure.runtime, .configuration] {
				model.updateDeveloperSimulation {
					$0.failure = kind
					$0.isInstalled = true
					$0.lifecycle = .ready
				}
				let failure = try #require(model.lifecycle.state.presentation.failure)
				#expect(!failure.blocksGameLaunch)
				#expect(!failure.message.contains("status 1"))
				#expect(await model.actions.launchFromDock(region: .global))
				#expect(model.lifecycle.state.presentation.failure == nil)
				#expect(model.developerSimulation?.failure == DeveloperSimulationState.Failure.none)
				model.actions.stopGame()
			}

			model.updateDeveloperSimulation {
				$0.failure = .configuration
				$0.isInstalled = false
			}
			#expect(model.lifecycle.state.presentation.failure?.blocksGameLaunch == true)
			#expect(await model.actions.launchFromDock(region: .global) == false)
		}

		@Test
		func simulatedRosettaFailureUsesTheModalAndKeepsItsIdentity() async throws {
			let api = CancellableBrandingAPI()
			let model = makeModel(
				api: api, installer: ControllableInstaller(), arguments: ["--developer-preview"])
			await api.waitForBrandingRequest()
			await api.resolveBranding()

			model.updateDeveloperSimulation { $0.rosettaMissing = true }
			let failure = try #require(model.lifecycle.state.presentation.failure)
			#expect(failure.code == .rosettaMissing)
			#expect(failure.context.operation == .intelTranslationPreflight)
			#expect(failure.context.region == nil)
			#expect(failure.blocksGameLaunch)
			#expect(
				failure.actions == [.installRosetta, .retry, .openTroubleshooting, .reportProblem])

			model.updateDeveloperSimulation { $0.isInstalled = false }
			#expect(model.lifecycle.state.presentation.failure == nil)
			model.updateDeveloperSimulation { $0.isInstalled = true }
			#expect(
				model.lifecycle.state.presentation.failure?.context.operation
					== .intelTranslationPreflight)
			model.updateDeveloperSimulation { $0.rosettaMissing = false }
			#expect(model.lifecycle.state.presentation.failure == nil)
		}

		@Test
		func simulatedRosettaRetryRechecksWithoutLaunchingOrCallingTheSystem() async throws {
			let api = CancellableBrandingAPI()
			let checks = TranslationCheckSequence(states: [.available])
			let model = makeModel(
				api: api, installer: ControllableInstaller(),
				checkIntelTranslation: { await checks.next() },
				arguments: ["--developer-preview"]
			)
			await api.waitForBrandingRequest()
			await api.resolveBranding()

			model.updateDeveloperSimulation { $0.rosettaMissing = true }
			let failureID = try #require(model.lifecycle.state.presentation.failure?.id)
			model.actions.launch()
			#expect(model.lifecycle.activity == .idle)
			#expect(await model.actions.launchFromDock(region: .global) == false)
			#expect(model.performRecoveryAction(.retry, failureID: failureID) == .completed)
			#expect(model.lifecycle.activity == .idle)
			#expect(model.lifecycle.state.readiness.intelTranslation == .rosettaMissing)
			#expect(
				model.lifecycle.state.presentation.failure?.context.operation
					== .intelTranslationPreflight)

			model.lifecycle.clearFailure()
			#expect(
				await model.actions.refreshIntelTranslationForUI(force: true) == .rosettaMissing)
			#expect(
				model.lifecycle.state.presentation.failure?.context.operation
					== .intelTranslationPreflight)
			#expect(await checks.count == 0)
		}

		@Test
		func simulatedRosettaInstallNeverFallsThroughToTheController() async {
			let api = CancellableBrandingAPI()
			let checks = TranslationCheckSequence(states: [.available])
			let installer = RosettaInstallationRecorder(status: 0)
			let model = makeModel(
				api: api,
				installer: ControllableInstaller(),
				checkIntelTranslation: { await checks.next() },
				installRosettaSystemSoftware: { await installer.install() },
				arguments: ["--developer-preview"]
			)
			await api.waitForBrandingRequest()
			await api.resolveBranding()

			model.updateDeveloperSimulation { $0.rosettaMissing = true }
			let result = await model.actions.installRosetta()

			#expect(result == .available)
			#expect(model.developerSimulation?.rosettaMissing == false)
			#expect(model.lifecycle.state.presentation.failure == nil)
			#expect(await checks.count == 0)
			#expect(await installer.count == 0)
		}
	}
#endif
