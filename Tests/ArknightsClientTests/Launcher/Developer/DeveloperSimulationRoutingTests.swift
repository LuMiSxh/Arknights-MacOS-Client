// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

#if DEBUG
	@MainActor
	struct DeveloperSimulationRoutingTests {
		@Test
		func simulatedActionsDoNotStartExternalRefreshOrInstallation() async {
			let api = CancellableBrandingAPI()
			let installer = ControllableInstaller()
			let model = makeModel(
				api: api,
				installer: installer,
				arguments: ["--developer-preview"]
			)
			await api.waitForBrandingRequest()
			await api.resolveBranding()
			let initialBrandingRequests = await api.brandingRequestCount()

			model.updateDeveloperSimulation {
				$0.installedRegions.insert(.japan)
				$0.selectedRegion = .japan
			}
			model.actions.selectRegion(.global)
			model.actions.openLauncherUpdate()
			_ = await model.actions.launcherUpdateCheckForOnboarding()
			let launched = await model.actions.launchFromDock(region: .japan)

			#expect(launched)
			#expect(await api.brandingRequestCount() == initialBrandingRequests)
			#expect(await installer.installationCount() == 0)
			#expect(model.installation.region == .japan)
			#expect(model.communication.launcherUpdateUserDriver.phase == .noUpdate)
			#expect(model.lifecycle.activity.isGameActive)
			model.communication.launcherUpdateUserDriver.dismissUpdateInstallation()
		}

		@Test
		func applyingTheSameSimulatedFailureKeepsItsPresentationIdentity() async {
			let api = CancellableBrandingAPI()
			let model = makeModel(
				api: api,
				installer: ControllableInstaller(),
				arguments: ["--developer-preview"]
			)
			await api.waitForBrandingRequest()
			await api.resolveBranding()

			var simulation = model.developerSimulation!
			simulation.failure = .runtime
			model.applyDeveloperSimulation(simulation)
			let firstID = model.lifecycle.failure?.id
			model.applyDeveloperSimulation(simulation)

			#expect(firstID != nil)
			#expect(model.lifecycle.failure?.id == firstID)
		}

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
			let failureID = model.lifecycle.failure!.id

			#expect(model.performRecoveryAction(.retry, failureID: failureID) == .completed)
			#expect(model.developerSimulation?.failure == DeveloperPreviewFailure.none)
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

			for kind in [DeveloperPreviewFailure.runtime, .configuration] {
				model.updateDeveloperSimulation {
					$0.failure = kind
					$0.isInstalled = true
					$0.lifecycle = .ready
				}
				let failure = try #require(model.lifecycle.failure)
				#expect(!failure.blocksGameLaunch)
				#expect(!failure.message.contains("status 1"))
				#expect(await model.actions.launchFromDock(region: .global))
				#expect(model.lifecycle.failure == nil)
				#expect(model.developerSimulation?.failure == DeveloperPreviewFailure.none)
				model.actions.stopGame()
			}

			model.updateDeveloperSimulation {
				$0.failure = .configuration
				$0.isInstalled = false
			}
			#expect(model.lifecycle.failure?.blocksGameLaunch == true)
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
			let failure = try #require(model.lifecycle.failure)
			#expect(failure.code == .limpet)
			#expect(failure.context.operation == .intelTranslationPreflight)
			#expect(failure.context.region == nil)
			#expect(failure.blocksGameLaunch)
			#expect(
				failure.actions == [.installRosetta, .retry, .openTroubleshooting, .reportProblem])

			model.updateDeveloperSimulation { $0.showVersionPill.toggle() }
			#expect(model.lifecycle.failure?.id == failure.id)
			model.updateDeveloperSimulation { $0.isInstalled = false }
			#expect(model.lifecycle.failure == nil)
			model.updateDeveloperSimulation { $0.isInstalled = true }
			#expect(model.lifecycle.failure?.context.operation == .intelTranslationPreflight)
			model.updateDeveloperSimulation { $0.rosettaMissing = false }
			#expect(model.lifecycle.failure == nil)
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
			let failureID = try #require(model.lifecycle.failure?.id)
			model.actions.launch()
			#expect(model.lifecycle.activity == .idle)
			#expect(await model.actions.launchFromDock(region: .global) == false)
			#expect(model.performRecoveryAction(.retry, failureID: failureID) == .completed)
			#expect(model.lifecycle.activity == .idle)
			#expect(model.lifecycle.intelTranslationState == .rosettaMissing)
			#expect(model.lifecycle.failure?.context.operation == .intelTranslationPreflight)

			model.lifecycle.clearFailure()
			#expect(
				await model.actions.refreshIntelTranslationForUI(force: true) == .rosettaMissing)
			#expect(model.lifecycle.failure?.context.operation == .intelTranslationPreflight)
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
			#expect(model.lifecycle.failure == nil)
			#expect(await checks.count == 0)
			#expect(await installer.count == 0)
		}
	}
#endif
