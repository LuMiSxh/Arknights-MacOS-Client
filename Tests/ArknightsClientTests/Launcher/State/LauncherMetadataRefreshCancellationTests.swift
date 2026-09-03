// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherMetadataRefreshCancellationTests {
	@Test
	func refreshOwnershipIsEstablishedAndCancelledSynchronously() async {
		let api = CancellableBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		model.refreshController.cancelRefresh()

		let task = model.refreshController.startRefresh()
		let requestID = model.lifecycle.refresh.requestID
		#expect(requestID != nil)

		model.refreshController.cancelRefresh()
		#expect(model.lifecycle.refresh == .idle)
		await task.value
		#expect(model.lifecycle.refresh == .idle)
	}

	@Test
	func installationCancellationInvalidatesMetadataBeforeTheTaskCanResume() async {
		let api = CancellableBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		model.refreshController.cancelRefresh()
		let task = model.refreshController.startRefresh()
		#expect(model.lifecycle.refresh.requestID != nil)

		model.refreshController.cancelForInstallationStart()
		#expect(model.lifecycle.refresh == .idle)
		await task.value
		#expect(model.lifecycle.refresh == .idle)
	}

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
