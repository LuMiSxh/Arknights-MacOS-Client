// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import ArknightsTestSupport
import Foundation

@testable import ArknightsGameInstallation

actor ProgressRecorder {
	private var recordedUpdates: [DownloadProgress] = []

	func record(_ update: DownloadProgress) {
		recordedUpdates.append(update)
	}

	func updates() -> [DownloadProgress] {
		recordedUpdates
	}
}

struct InstallerFixture {
	let directory: URL
	let destination: URL
	let configuration: GameConfiguration
	let item: ManifestFile
	let source: String
	let baseURL: URL
	let installer: GameInstaller
	let route: StubURLProtocol.Route

	var partial: URL { destination.appendingPathExtension("part") }

	func remove() {
		try? FileManager.default.removeItem(at: directory)
	}
}

struct InstallerAPI: LauncherAPIProviding {
	let manifest: GameManifest
	let cdn: CDNConfiguration

	func gameConfiguration(region: GameRegion) async throws -> GameConfiguration {
		throw CancellationError()
	}
	func branding(region: GameRegion) async throws -> LauncherBranding { throw CancellationError() }
	func cdnConfiguration(region: GameRegion) async throws -> CDNConfiguration { cdn }
	func manifest(
		for configuration: GameConfiguration,
		region: GameRegion
	) async throws -> GameManifest { manifest }
}
