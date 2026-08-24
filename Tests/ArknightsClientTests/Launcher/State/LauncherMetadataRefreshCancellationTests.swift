// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherMetadataRefreshCancellationTests {
	@Test
	func installationCancelsTheTrackedMetadataRefresh() async throws {
		let api = CancellableBrandingAPI()
		let installer = ControllableInstaller()
		let model = makeModel(api: api, installer: installer)
		await api.waitForBrandingRequests(1)
		try #require(
			await waitForCondition {
				model.installation.configuration != nil
			})

		model.installation.installOrUpdate()

		await api.waitForCancellations(1)
		await installer.waitForInstallationStart()
		#expect(model.installation.isDownloading)

		model.installation.cancelDownload()
		await installer.waitForCancellationRequest()
		await installer.acknowledgeCancellation()
		await waitForDownloadToStop(model)
	}
}
