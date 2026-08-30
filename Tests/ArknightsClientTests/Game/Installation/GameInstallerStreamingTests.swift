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
		let fixture = try Self.makeFixture(body: body)
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
		#expect(updates.first?.networkDownloadedBytes == 0)
		#expect(updates.last?.downloadedBytes == Int64(body.count))
		#expect(updates.last?.networkDownloadedBytes == Int64(body.count - partialSize))
	}

	@Test
	func installerTruncatesAPartialFileWhenTheServerIgnoresRange() async throws {
		let body = Data(repeating: 0x5A, count: 384 * 1_024)
		let fixture = try Self.makeFixture(body: body)
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

	@Test
	func installerDownloadsOfficialLeadingSlashManifestPaths() async throws {
		let body = Data("game".utf8)
		let fixture = try Self.makeFixture(
			body: body,
			source: "/Arknights_JP-36.7.23-game",
			relativePath: "/Arknights.exe"
		)
		defer { fixture.remove() }
		StreamingURLProtocol.handler = { request in
			#expect(
				request.url?.absoluteString
					== "https://download.test/Arknights_JP-36.7.23-game/Arknights.exe"
			)
			return (Self.response(url: request.url!, status: 200), body)
		}
		defer { StreamingURLProtocol.handler = nil }

		_ = try await fixture.installer.install(
			configuration: fixture.configuration,
			region: .japan,
			into: fixture.directory,
			progress: { _ in }
		)

		#expect(try Data(contentsOf: fixture.destination) == body)
	}

	@Test
	func installerStopsWritingWhenAResponseExceedsTheManifestSize() async throws {
		let body = Data("game".utf8)
		let fixture = try Self.makeFixture(body: body)
		defer { fixture.remove() }
		StreamingURLProtocol.handler = { request in
			return (
				Self.response(url: request.url!, status: 200),
				body + Data(repeating: 0xFF, count: 64 * 1_024)
			)
		}
		defer { StreamingURLProtocol.handler = nil }

		do {
			_ = try await fixture.installer.download(
				fixture.item,
				source: fixture.source,
				baseURL: fixture.baseURL,
				installDirectory: fixture.directory,
				counter: ProgressCounter(
					totalBytes: fixture.item.byteCount,
					totalFiles: 1
				),
				progress: { _ in }
			)
			Issue.record("Expected the oversized response to be rejected")
		} catch LauncherError.downloadedSizeMismatch(_, let expected, let actual) {
			#expect(expected == Int64(body.count))
			#expect(actual > expected)
		} catch {
			Issue.record("Unexpected installer error: \(error)")
		}

		let partialSize =
			try FileManager.default.attributesOfItem(
				atPath: fixture.partial.path
			)[.size] as? NSNumber
		#expect(partialSize?.int64Value == 0)
	}

	@Test
	func checksumRetryRollsBackAttemptProgress() async throws {
		let body = Data("correct".utf8)
		let fixture = try Self.makeFixture(body: body)
		defer { fixture.remove() }
		var requestCount = 0
		StreamingURLProtocol.handler = { request in
			requestCount += 1
			let responseBody =
				requestCount == 1
				? Data(repeating: 0xFF, count: body.count)
				: body
			return (Self.response(url: request.url!, status: 200), responseBody)
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
		#expect(requestCount >= 2)
		#expect(updates.contains(where: { $0.downloadedBytes == 0 }))
		#expect(updates.contains(where: { $0.networkDownloadedBytes == 0 }))
		#expect(updates.allSatisfy { $0.downloadedBytes <= Int64(body.count) })
		#expect(updates.last?.downloadedBytes == Int64(body.count))
		#expect(updates.last?.networkDownloadedBytes == Int64(body.count))
		#expect(try Data(contentsOf: fixture.destination) == body)
	}

	static func makeFixture(
		body: Data,
		source: String = "payload",
		relativePath: String = "bin/game.dat",
		protocolClass: URLProtocol.Type = StreamingURLProtocol.self
	) throws -> InstallerFixture {
		let baseURL = URL(string: "https://download.test")!
		let directory = FileManager.default.temporaryDirectory.appending(
			path: "GameInstallerStreamingTests-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		let destination = directory.appending(
			path: try GameInstaller.safeRelativePath(relativePath)
		)
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
		let item = ManifestFile(
			path: relativePath,
			hash: checksum.decimalString,
			size: String(body.count)
		)
		let api = InstallerAPI(
			manifest: GameManifest(
				source: source,
				file: [item]
			),
			cdn: CDNConfiguration(primaryCdn: baseURL, backUpCdn: baseURL)
		)
		let sessionConfiguration = URLSessionConfiguration.ephemeral
		sessionConfiguration.protocolClasses = [protocolClass]
		return InstallerFixture(
			directory: directory,
			destination: destination,
			configuration: configuration,
			item: item,
			source: source,
			baseURL: baseURL,
			installer: GameInstaller(
				api: api,
				session: URLSession(configuration: sessionConfiguration),
				compatibilityManager: GameCompatibilityManager()
			)
		)
	}

	static func response(url: URL, status: Int) -> HTTPURLResponse {
		HTTPURLResponse(
			url: url,
			statusCode: status,
			httpVersion: "HTTP/1.1",
			headerFields: nil
		)!
	}
}

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

final class StreamingURLProtocol: URLProtocol, @unchecked Sendable {
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
	func chunkRanges(size: Int) -> [Range<Int>] {
		stride(from: 0, to: count, by: size).map { start in
			start..<Swift.min(start + size, count)
		}
	}
}
