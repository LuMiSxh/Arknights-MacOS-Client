// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherInstallationBrandingConcurrencyTests {
	@Test
	func installationStartKeepsCurrentJapanBrandingAssetsAlive() async throws {
		BlockingInstallationArtworkURLProtocol.reset()
		defer {
			BlockingInstallationArtworkURLProtocol.releaseArtwork()
			BlockingInstallationArtworkURLProtocol.reset()
		}
		let directory = FileManager.default.temporaryDirectory.appending(
			path: "InstallationBrandingCache.\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? FileManager.default.removeItem(at: directory) }
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [BlockingInstallationArtworkURLProtocol.self]
		let cache = ArtworkCache(
			session: URLSession(configuration: configuration),
			directory: directory
		)
		let api = BlockingBrandingAPI()
		let installer = ControllableInstaller()
		let model = makeModel(api: api, installer: installer, artworkCache: cache)

		await api.waitForBrandingRequest()
		#expect(model.refreshController.selectRegion(.japan))
		await api.waitForBrandingRequests(2)
		await api.resolveBranding(
			LauncherBranding(
				launcherBackgroundImage: URL(string: "https://example.com/japan-artwork.png"),
				launcherBackgroundImageCRC64: "japan-artwork",
				copyrightInformation: nil,
				privacyPolicy: nil,
				userAgreement: nil,
				noticePopOpen: nil,
				noticeContent: nil
			)
		)

		#expect(
			await waitForCondition {
				BlockingInstallationArtworkURLProtocol.isArtworkRequestStarted
			})
		try #require(await waitForCondition { model.installation.configuration != nil })

		model.installation.installOrUpdate()
		await installer.waitForInstallationStart()
		#expect(model.installation.isDownloading)

		BlockingInstallationArtworkURLProtocol.releaseArtwork()
		let artworkApplied = await waitForCondition(timeout: .seconds(5)) {
			model.customization.activeThemeCacheKey == "official.japan.japan-artwork"
		}
		#expect(artworkApplied)
		#expect(model.customization.officialLogo != nil)

		model.installation.cancelDownload()
		await installer.waitForCancellationRequest()
		await installer.acknowledgeCancellation()
		await waitForDownloadToStop(model)
	}
}
