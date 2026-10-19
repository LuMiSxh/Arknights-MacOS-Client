// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import ArknightsTestSupport
import Foundation

@testable import ArknightsGameInstallation

let installerTestConfiguration = GameConfiguration(
	gameLowestVersion: "1.0.0",
	gameLatestVersion: "1.0.0",
	gameLatestFilePath: "manifest.json",
	gameStartExeName: "Arknights",
	gameStartParams: [],
	gameUninstallScript: "uninstall.exe",
	decompressionSize: "1 MB"
)

actor ProgressRecorder {
	private var recordedUpdates: [DownloadProgress] = []

	func record(_ update: DownloadProgress) {
		recordedUpdates.append(update)
	}

	func updates() -> [DownloadProgress] {
		recordedUpdates
	}
}

/// A game install directory under a fresh temporary root, with one manifest file served by `route`.
struct InstallerFixture {
	let temporary: TemporaryDirectory
	let directory: URL
	let destination: URL
	let item: ManifestFile
	let source: String
	let baseURL: URL
	let installer: GameInstaller
	let route: StubURLProtocol.Route

	var partial: URL { destination.appendingPathExtension("part") }

	func remove() {
		temporary.remove()
	}
}

extension InstallerFixture {
	/// Builds a fixture whose manifest lists one file, `relativePath`, that holds `body`.
	static func make(
		body: Data,
		source: String = "payload",
		relativePath: String = "bin/game.dat",
		protocolClass: URLProtocol.Type? = nil
	) throws -> InstallerFixture {
		let temporary = try TemporaryDirectory("InstallerFixture")
		let baseURL = URL(string: "https://download.yo-star.com")!
		let directory = temporary.url.appending(path: "install", directoryHint: .isDirectory)
		let destination = directory.appending(
			path: try GameInstaller.safeRelativePath(relativePath)
		)
		try FileManager.default.createDirectory(
			at: destination.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		var checksum = CRC64()
		checksum.update(body)
		let item = ManifestFile(
			path: relativePath,
			hash: checksum.decimalString,
			size: String(body.count)
		)
		let api = InstallerAPI(
			manifest: GameManifest(source: source, file: [item]),
			cdn: CDNConfiguration(primaryCdn: baseURL, backUpCdn: baseURL)
		)
		let route = StubURLProtocol.Route(chunkSize: 32 * 1_024)
		let sessionConfiguration = URLSessionConfiguration.ephemeral
		if let protocolClass {
			sessionConfiguration.protocolClasses = [protocolClass]
		} else {
			route.configure(sessionConfiguration)
		}
		return InstallerFixture(
			temporary: temporary,
			directory: directory,
			destination: destination,
			item: item,
			source: source,
			baseURL: baseURL,
			installer: GameInstaller(
				api: api,
				session: URLSession(configuration: sessionConfiguration),
				compatibilityManager: GameCompatibilityManager()
			),
			route: route
		)
	}

	func install(
		region: GameRegion = .global,
		progress: @escaping @Sendable (DownloadProgress) async -> Void = { _ in }
	) async throws -> InstallResult {
		try await installer.install(
			configuration: installerTestConfiguration,
			region: region,
			into: directory,
			progress: progress
		)
	}

	func download(
		baseline: Int,
		recorder: ProgressRecorder = ProgressRecorder()
	) async throws -> Int64 {
		try await withTestInstallDirectory(at: directory) { installDirectory in
			try await installer.download(
				item,
				source: source,
				baseURL: baseURL,
				installDirectory: installDirectory,
				counter: ProgressCounter(
					totalBytes: item.byteCount,
					totalFiles: 1,
					downloadedBytes: Int64(baseline)
				),
				progress: { update in await recorder.record(update) }
			)
		}
	}

	func writeResumeMetadata(manifestHash: String) async throws {
		try await withTestInstallDirectory(at: directory) { installDirectory in
			let staging = try installDirectory.stagingDirectory(
				named: AppConstants.Game.installerStagingDirectoryName
			)
			try installer.writeResumeMetadata(
				InstallerResumeMetadata(
					manifestHash: manifestHash,
					entityTag: "\"v0\"",
					lastModified: nil
				),
				to: installer.resumeMetadataFile(for: item.path, in: staging)
			)
		}
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
