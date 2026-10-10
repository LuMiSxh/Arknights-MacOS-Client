// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

#if DEBUG
	@MainActor
	struct LauncherActionsSimulationTests {
		@Test
		func everySimulatedActionLeavesTheRealControllersUntouched() async {
			let api = CancellableBrandingAPI()
			let installer = ControllableInstaller()
			let checks = TranslationCheckSequence(states: [.available])
			let rosetta = RosettaInstallationRecorder(status: 0)
			let model = makeModel(
				api: api,
				installer: installer,
				checkIntelTranslation: { await checks.next() },
				installRosettaSystemSoftware: { await rosetta.install() },
				arguments: ["--developer-preview"]
			)
			await api.waitForBrandingRequest()
			await api.resolveBranding()
			let initialBrandingRequests = await api.brandingRequestCount()
			model.updateDeveloperSimulation {
				$0.rosettaMissing = true
				$0.installedRegions.insert(.japan)
			}

			let actions = model.actions
			_ = actions.canRequestDockLaunch
			actions.selectRegion(.japan)
			actions.installOrUpdate()
			actions.repairGame()
			actions.cancelDownload()
			actions.checkGameUpdates()
			actions.checkLauncherUpdates()
			actions.checkAnnouncements()
			_ = await actions.launcherUpdateCheckForOnboarding()
			actions.openLauncherUpdate()
			_ = await actions.refreshIntelTranslationForUI(force: true)
			actions.launch()
			actions.confirmACEWarningAndLaunch()
			actions.cancelACEWarning()
			actions.stopGame()
			actions.stopGameForApplicationTermination()
			_ = await actions.launchFromDock(region: .japan)
			actions.chooseInstallDirectory()
			actions.locateExistingInstallation()
			actions.resetAllLauncherSettings()
			actions.uninstallGame()
			actions.resetArtwork()
			_ = await actions.installRosetta()

			#expect(await installer.installationCount() == 0)
			#expect(await api.brandingRequestCount() == initialBrandingRequests)
			#expect(await checks.count == 0)
			#expect(await rosetta.count == 0)
			#expect(!model.installation.isDownloading)
			#expect(model.pendingACEWarningRegion == nil)
			model.communication.launcherUpdateUserDriver.dismissUpdateInstallation()
		}

		@Test
		func liveActionsReachTheRealControllersWithoutASimulation() async {
			let api = CancellableBrandingAPI()
			let model = makeModel(api: api, installer: ControllableInstaller())
			await api.waitForBrandingRequest()
			await api.resolveBranding()

			#expect(model.developerSimulation == nil)
			model.actions.selectRegion(.japan)
			await api.waitForBrandingRequests(2)

			#expect(model.installation.region == .japan)
			await api.resolveBranding()
		}
	}
#endif
