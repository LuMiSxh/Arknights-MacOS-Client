// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(
	"Yostar launcher live contract",
	.enabled(if: LiveContractGate.isEnabled, Comment(rawValue: LiveContractGate.disabledComment)),
	.serialized
)
struct YostarLiveContractSmokeTests {
	@Test
	func supportedRegionsExposeAUsableInstallationContract() async throws {
		let api = LauncherAPI()
		let validationRoot = FileManager.default.temporaryDirectory.appending(
			path: "ArknightsClientLiveContracts-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		let installer = GameInstaller(
			api: api,
			compatibilityManager: GameCompatibilityManager(active: [])
		)

		for region in GameRegion.allCases {
			let configuration = try await api.gameConfiguration(region: region)
			let cdn = try await api.cdnConfiguration(region: region)
			let manifest = try await api.manifest(for: configuration, region: region)

			#expect(!configuration.gameLatestVersion.isEmpty, "Missing version for \(region)")
			#expect(
				!configuration.gameLatestFilePath.isEmpty, "Missing manifest path for \(region)")
			#expect(!configuration.executableName.isEmpty, "Missing executable for \(region)")
			#expect(cdn.primaryCdn.scheme == "https", "Invalid primary CDN scheme for \(region)")
			#expect(cdn.primaryCdn.host != nil, "Missing primary CDN host for \(region)")
			#expect(cdn.backUpCdn.scheme == "https", "Invalid backup CDN scheme for \(region)")
			#expect(cdn.backUpCdn.host != nil, "Missing backup CDN host for \(region)")
			#expect(!manifest.source.isEmpty, "Missing download source for \(region)")
			#expect(!manifest.file.isEmpty, "Empty manifest for \(region)")
			try installer.validateManifest(
				manifest,
				inside: validationRoot.appending(path: region.rawValue, directoryHint: .isDirectory)
			)
			for file in manifest.file {
				#expect(!file.hash.isEmpty, "Missing checksum for \(file.path) in \(region)")
				#expect(file.byteCount > 0, "Invalid size for \(file.path) in \(region)")
			}
		}
	}
}
