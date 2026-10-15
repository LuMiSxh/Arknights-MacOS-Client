// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore
@testable import ArknightsCustomization
@testable import ArknightsGameInstallation
@testable import ArknightsLauncherUI

@MainActor
struct LauncherViewModelConcurrencyTests {
	@Test
	func activeGameSessionRejectsInstallationAndGameFileMaintenance() async {
		let api = BlockingBrandingAPI()
		let installer = ControllableInstaller()
		let model = makeModel(api: api, installer: installer)
		await api.waitForBrandingRequest()
		model.lifecycle.simulateActivity(.runningGame(sessionID: UUID(), processIdentifier: 42))

		model.installation.repairGame()

		#expect(!model.installation.canInstall)
		#expect(!model.installation.canModifyGameFiles)
		#expect(model.gameSession.isGameActive)
		#expect(await installer.installationCount() == 0)
		await api.resolveBranding()
	}

	@Test
	func staleRefreshThatIgnoresCancellationDoesNotHideInstallationProgress() async throws {
		let api = BlockingBrandingAPI()
		let installer = ControllableInstaller()
		let model = makeModel(api: api, installer: installer)

		await api.waitForBrandingRequest()
		model.installation.installOrUpdate()
		await installer.waitForInstallationStart()
		await installer.sendProgress()

		#expect(model.installation.isDownloading)
		#expect(model.lifecycle.activity.isInstalling)
		#expect(model.installation.progress?.downloadedBytes == 50)

		await api.resolveBranding()
		await Task.yield()

		#expect(model.installation.isDownloading)
		#expect(model.lifecycle.activity.isInstalling)
		#expect(model.installation.progress?.downloadedBytes == 50)

		await installer.completeSuccessfully()
		await waitForDownloadToStop(model)
	}

	@Test
	func secondInstallIsRejectedUntilCancelledInstallerAcknowledgesCancellation() async throws {
		let api = BlockingBrandingAPI()
		let installer = ControllableInstaller()
		let model = makeModel(api: api, installer: installer)

		await api.waitForBrandingRequest()
		model.installation.installOrUpdate()
		await installer.waitForInstallationStart()

		model.installation.installOrUpdate()
		#expect(await installer.installationCount() == 1)

		model.installation.cancelDownload()
		await installer.waitForCancellationRequest()
		model.installation.installOrUpdate()
		#expect(await installer.installationCount() == 1)
		#expect(model.installation.isDownloading)

		await installer.acknowledgeCancellation()
		await waitForDownloadToStop(model)
		#expect(!model.lifecycle.state.presentation.status.message.isEmpty)
		await api.resolveBranding()
	}

}
