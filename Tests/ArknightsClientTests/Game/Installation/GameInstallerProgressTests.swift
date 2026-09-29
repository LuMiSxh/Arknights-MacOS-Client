// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct GameInstallerProgressTests {
	@Test(arguments: [false, true])
	func oversizedPartialDoesNotSubtractReusedFileProgress(
		hasStaleManifestMetadata: Bool
	) async throws {
		let manager = FileManager.default
		let root = manager.temporaryDirectory.appending(
			path: "GameInstallerProgressTests-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? manager.removeItem(at: root) }
		try manager.createDirectory(at: root, withIntermediateDirectories: true)
		let reused = Data(repeating: 0x31, count: 300)
		let pending = Data(repeating: 0x72, count: 700)
		let reusedItem = Self.manifestFile(path: "reused.bin", data: reused)
		let pendingItem = Self.manifestFile(path: "pending.bin", data: pending)
		try reused.write(to: root.appending(path: reusedItem.path))
		try Data(repeating: 0xFF, count: 1_000).write(
			to: root.appending(path: pendingItem.path + ".part")
		)
		let manifest = GameManifest(source: "payload", file: [reusedItem, pendingItem])
		let baseURL = URL(string: "https://download.test")!
		let api = InstallerAPI(
			manifest: manifest,
			cdn: CDNConfiguration(primaryCdn: baseURL, backUpCdn: baseURL)
		)
		let sessionConfiguration = URLSessionConfiguration.ephemeral
		sessionConfiguration.protocolClasses = [ProgressBaselineURLProtocol.self]
		let installer = GameInstaller(
			api: api,
			session: URLSession(configuration: sessionConfiguration),
			compatibilityManager: GameCompatibilityManager()
		)
		if hasStaleManifestMetadata {
			let install = try InstallerInstallDirectory(at: root)
			let staging = try install.stagingDirectory(
				named: AppConstants.Game.installerStagingDirectoryName
			)
			let metadata = installer.resumeMetadataFile(for: pendingItem.path, in: staging)
			try installer.writeResumeMetadata(
				InstallerResumeMetadata(
					manifestHash: "old-manifest",
					entityTag: nil,
					lastModified: nil
				),
				to: metadata
			)
		}

		ProgressBaselineURLProtocol.handler = { request in
			#expect(request.value(forHTTPHeaderField: "Range") == nil)
			return (
				GameInstallerStreamingTests.response(url: request.url!, status: 200),
				pending
			)
		}
		defer { ProgressBaselineURLProtocol.handler = nil }
		let recorder = ProgressRecorder()

		let result = try await installer.install(
			configuration: Self.configuration,
			region: .global,
			into: root,
			progress: { update in await recorder.record(update) }
		)

		let updates = await recorder.updates()
		#expect(result.downloadedBytes == Int64(pending.count))
		#expect(updates.contains(where: { $0.downloadedBytes == Int64(reused.count) }))
		#expect(updates.last?.downloadedBytes == Int64(reused.count + pending.count))
		#expect(updates.last?.totalBytes == Int64(reused.count + pending.count))
		#expect(updates.last?.completedFiles == 2)
		#expect(try Data(contentsOf: root.appending(path: "reused.bin")) == reused)
		#expect(try Data(contentsOf: root.appending(path: "pending.bin")) == pending)
	}

	private static let configuration = GameConfiguration(
		gameLowestVersion: "1.0.0",
		gameLatestVersion: "1.0.0",
		gameLatestFilePath: "manifest.json",
		gameStartExeName: "Arknights",
		gameStartParams: [],
		gameUninstallScript: "uninstall.exe",
		decompressionSize: "1 MB"
	)

	private static func manifestFile(path: String, data: Data) -> ManifestFile {
		var checksum = CRC64()
		checksum.update(data)
		return ManifestFile(path: path, hash: checksum.decimalString, size: String(data.count))
	}
}

private final class ProgressBaselineURLProtocol: URLProtocol, @unchecked Sendable {
	nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		guard let result = Self.handler?(request) else {
			client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
			return
		}
		client?.urlProtocol(self, didReceive: result.0, cacheStoragePolicy: .notAllowed)
		client?.urlProtocol(self, didLoad: result.1)
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}
}
