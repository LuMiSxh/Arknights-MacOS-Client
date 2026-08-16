// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct GameInstallerStreamingTests {
	@Test
	func installerResumesAPartialFileWithBufferedChunks() async throws {
		let body = Data(repeating: 0xA5, count: 512 * 1_024)
		let partialSize = 96 * 1_024
		let fixture = try makeFixture(body: body)
		defer { fixture.remove() }
		try body.prefix(partialSize).write(to: fixture.partial)
		StreamingURLProtocol.handler = { request in
			#expect(request.value(forHTTPHeaderField: "Range") == "bytes=98304-")
			return (
				Self.response(url: request.url!, status: 206),
				Data(body.dropFirst(partialSize))
			)
		}
		defer { StreamingURLProtocol.handler = nil }
		let recorder = ProgressRecorder()

		let result = try await fixture.installer.install(
			configuration: fixture.configuration,
			region: .global,
			into: fixture.directory,
			progress: { update in await recorder.record(update) }
		)

		let updates = await recorder.updates()
		#expect(try Data(contentsOf: fixture.destination) == body)
		#expect(result.downloadedBytes == Int64(body.count))
		#expect(updates.first?.downloadedBytes == Int64(partialSize))
		#expect(updates.last?.downloadedBytes == Int64(body.count))
	}

	@Test
	func installerTruncatesAPartialFileWhenTheServerIgnoresRange() async throws {
		let body = Data(repeating: 0x5A, count: 384 * 1_024)
		let fixture = try makeFixture(body: body)
		defer { fixture.remove() }
		try Data(repeating: 0xFF, count: 64 * 1_024).write(to: fixture.partial)
		StreamingURLProtocol.handler = { request in
			#expect(request.value(forHTTPHeaderField: "Range") == "bytes=65536-")
			return (Self.response(url: request.url!, status: 200), body)
		}
		defer { StreamingURLProtocol.handler = nil }
		let recorder = ProgressRecorder()

		_ = try await fixture.installer.install(
			configuration: fixture.configuration,
			region: .global,
			into: fixture.directory,
			progress: { update in await recorder.record(update) }
		)

		let updates = await recorder.updates()
		#expect(try Data(contentsOf: fixture.destination) == body)
		#expect(updates.first?.downloadedBytes == Int64(64 * 1_024))
		#expect(updates.contains(where: { $0.downloadedBytes == 0 }))
		#expect(updates.last?.downloadedBytes == Int64(body.count))
	}

	private func makeFixture(body: Data) throws -> InstallerFixture {
		let directory = FileManager.default.temporaryDirectory.appending(
			path: "GameInstallerStreamingTests.(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		let relativePath = "bin/game.dat"
		let destination = directory.appending(path: relativePath)
		try FileManager.default.createDirectory(
			at: destination.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		var checksum = CRC64()
		checksum.update(body)
		let configuration = GameConfiguration(
			gameLowestVersion: "1.0.0",
			gameLatestVersion: "1.0.0",
			gameLatestFilePath: "manifest.json",
			gameStartExeName: "Arknights",
			gameStartParams: [],
			gameUninstallScript: "uninstall.exe",
			decompressionSize: "1 MB"
		)
		let baseURL = URL(string: "https://download.test/")!
		let api = InstallerAPI(
			manifest: GameManifest(
				source: "payload",
				file: [
					ManifestFile(
						path: relativePath,
						hash: checksum.decimalString,
						size: String(body.count)
					)
				]
			),
			cdn: CDNConfiguration(primaryCdn: baseURL, backUpCdn: baseURL)
		)
		let sessionConfiguration = URLSessionConfiguration.ephemeral
		sessionConfiguration.protocolClasses = [StreamingURLProtocol.self]
		return InstallerFixture(
			directory: directory,
			destination: destination,
			configuration: configuration,
			installer: GameInstaller(
				api: api,
				session: URLSession(configuration: sessionConfiguration)
			)
		)
	}

	private static func response(url: URL, status: Int) -> HTTPURLResponse {
		HTTPURLResponse(
			url: url,
			statusCode: status,
			httpVersion: "HTTP/1.1",
			headerFields: nil
		)!
	}
}

private actor ProgressRecorder {
	private var recordedUpdates: [DownloadProgress] = []

	func record(_ update: DownloadProgress) {
		recordedUpdates.append(update)
	}

	func updates() -> [DownloadProgress] {
		recordedUpdates
	}
}

private struct InstallerFixture {
	let directory: URL
	let destination: URL
	let configuration: GameConfiguration
	let installer: GameInstaller

	var partial: URL { destination.appendingPathExtension("part") }

	func remove() {
		try? FileManager.default.removeItem(at: directory)
	}
}

private struct InstallerAPI: LauncherAPIProviding {
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

private final class StreamingURLProtocol: URLProtocol, @unchecked Sendable {
	nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		guard let result = Self.handler?(request) else {
			client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
			return
		}
		client?.urlProtocol(self, didReceive: result.0, cacheStoragePolicy: .notAllowed)
		for range in result.1.chunkRanges(size: 32 * 1_024) {
			client?.urlProtocol(self, didLoad: result.1.subdata(in: range))
		}
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}
}

extension Data {
	fileprivate func chunkRanges(size: Int) -> [Range<Int>] {
		stride(from: 0, to: count, by: size).map { start in
			start..<Swift.min(start + size, count)
		}
	}
}
