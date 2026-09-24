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
			model.selectRegion(.global)
			model.openLauncherUpdate()
			_ = await model.launcherUpdateCheckForOnboarding()
			let launched = await model.launchFromDock(region: .japan)

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
		func simulatedRosettaInstallNeverFallsThroughToTheController() async {
			let api = CancellableBrandingAPI()
			let model = makeModel(
				api: api,
				installer: ControllableInstaller(),
				arguments: ["--developer-preview"]
			)
			await api.waitForBrandingRequest()
			await api.resolveBranding()

			let result = await model.installRosetta()

			#expect(result == .available)
			#expect(model.developerSimulation?.rosettaMissing == false)
		}
	}
#endif
