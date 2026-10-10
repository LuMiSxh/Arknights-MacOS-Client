// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

/// Pins how a single download attempt reconciles its `.part` file and progress with the
/// server's answer, independent of how `GameInstaller.download` is structured internally.
@Suite(.serialized)
struct GameInstallerRollbackTests {
	@Test
	func staleResumeMetadataRestartsFromZeroAndRemovesCountedBytes() async throws {
		let body = Data("game".utf8)
		let fixture = try GameInstallerStreamingTests.makeFixture(
			body: body, protocolClass: RollbackURLProtocol.self)
		defer { fixture.remove() }
		try Data("ga".utf8).write(to: fixture.partial)
		try await Self.writeMetadata(manifestHash: "0", for: fixture)
		RollbackURLProtocol.handler = { request in
			#expect(request.value(forHTTPHeaderField: "Range") == nil)
			return (GameInstallerStreamingTests.response(url: request.url!, status: 200), body)
		}
		defer { RollbackURLProtocol.handler = nil }
		let recorder = ProgressRecorder()

		let networkBytes = try await Self.download(fixture, baseline: 2, recorder: recorder)

		#expect(networkBytes == Int64(body.count))
		#expect(try Data(contentsOf: fixture.destination) == body)
		#expect(await recorder.updates().contains { $0.downloadedBytes == 0 })
	}

	@Test
	func completePartialPromotesWithoutOpeningANetworkRequest() async throws {
		let body = Data("game".utf8)
		let fixture = try GameInstallerStreamingTests.makeFixture(
			body: body, protocolClass: RollbackURLProtocol.self)
		defer { fixture.remove() }
		try body.write(to: fixture.partial)
		var requestCount = 0
		RollbackURLProtocol.handler = { request in
			requestCount += 1
			return (GameInstallerStreamingTests.response(url: request.url!, status: 200), body)
		}
		defer { RollbackURLProtocol.handler = nil }

		let networkBytes = try await Self.download(fixture, baseline: body.count)

		#expect(networkBytes == 0)
		#expect(requestCount == 0)
		#expect(try Data(contentsOf: fixture.destination) == body)
		#expect(!FileManager.default.fileExists(atPath: fixture.partial.path))
	}

	@Test
	func unsuccessfulStatusKeepsTheResumablePartial() async throws {
		let fixture = try GameInstallerStreamingTests.makeFixture(
			body: Data("game".utf8), protocolClass: RollbackURLProtocol.self)
		defer { fixture.remove() }
		try Data("ga".utf8).write(to: fixture.partial)
		RollbackURLProtocol.handler = { request in
			(GameInstallerStreamingTests.response(url: request.url!, status: 404), Data())
		}
		defer { RollbackURLProtocol.handler = nil }

		do {
			_ = try await Self.download(fixture, baseline: 2)
			Issue.record("Expected the 404 response to be rejected")
		} catch LauncherError.invalidDownloadResponse(let status, let path) {
			#expect(status == 404)
			#expect(path == fixture.item.path)
		} catch {
			Issue.record("Unexpected installer error: \(error)")
		}

		#expect(try Data(contentsOf: fixture.partial) == Data("ga".utf8))
		#expect(!FileManager.default.fileExists(atPath: fixture.destination.path))
	}

	@Test(arguments: [
		("body longer than the declared range", "bytes 1-2/4", "ome"),
		("body shorter than the declared range", "bytes 1-3/4", "om"),
	])
	func mismatchedRangeBodyTruncatesBackToTheResumeOffset(
		_ name: String,
		contentRange: String,
		payload: String
	) async throws {
		let fixture = try GameInstallerStreamingTests.makeFixture(
			body: Data("game".utf8), protocolClass: RollbackURLProtocol.self)
		defer { fixture.remove() }
		try Data("g".utf8).write(to: fixture.partial)
		RollbackURLProtocol.handler = { request in
			#expect(request.value(forHTTPHeaderField: "Range") == "bytes=1-")
			return (
				GameInstallerStreamingTests.response(
					url: request.url!,
					status: 206,
					headers: ["Content-Range": contentRange]
				),
				Data(payload.utf8)
			)
		}
		defer { RollbackURLProtocol.handler = nil }
		let recorder = ProgressRecorder()

		do {
			_ = try await Self.download(fixture, baseline: 1, recorder: recorder)
			Issue.record("Expected \(name) to be rejected")
		} catch LauncherError.invalidResponse {
		} catch {
			Issue.record("Unexpected installer error: \(error)")
		}

		#expect(try Data(contentsOf: fixture.partial) == Data("g".utf8))
		let last = await recorder.updates().last
		#expect(last?.downloadedBytes == 1)
		#expect(last?.networkDownloadedBytes == 0)
	}

	@Test
	func checksumMismatchEmptiesThePartialAndRemovesItsCountedBytes() async throws {
		let fixture = try GameInstallerStreamingTests.makeFixture(
			body: Data("game".utf8), protocolClass: RollbackURLProtocol.self)
		defer { fixture.remove() }
		try Data("ga".utf8).write(to: fixture.partial)
		RollbackURLProtocol.handler = { request in
			(
				GameInstallerStreamingTests.response(
					url: request.url!,
					status: 206,
					headers: ["Content-Range": "bytes 2-3/4"]
				),
				Data("xx".utf8)
			)
		}
		defer { RollbackURLProtocol.handler = nil }
		let recorder = ProgressRecorder()

		do {
			_ = try await Self.download(fixture, baseline: 2, recorder: recorder)
			Issue.record("Expected the corrupted file to fail verification")
		} catch LauncherError.checksumMismatch(let path, _, _) {
			#expect(path == fixture.item.path)
		} catch {
			Issue.record("Unexpected installer error: \(error)")
		}

		#expect(try Data(contentsOf: fixture.partial).isEmpty)
		#expect(!FileManager.default.fileExists(atPath: fixture.destination.path))
		let last = await recorder.updates().last
		#expect(last?.downloadedBytes == 0)
		#expect(last?.networkDownloadedBytes == 0)
	}

	@Test
	func cancelledDownloadLeavesTheResumablePartialUntouched() async throws {
		let fixture = try GameInstallerStreamingTests.makeFixture(
			body: Data("game".utf8), protocolClass: RollbackURLProtocol.self)
		defer { fixture.remove() }
		try Data("ga".utf8).write(to: fixture.partial)
		var requestCount = 0
		RollbackURLProtocol.handler = { request in
			requestCount += 1
			return (GameInstallerStreamingTests.response(url: request.url!, status: 200), Data())
		}
		defer { RollbackURLProtocol.handler = nil }

		let task = Task {
			withUnsafeCurrentTask { $0?.cancel() }
			return try await Self.download(fixture, baseline: 2)
		}
		await #expect(throws: CancellationError.self) { try await task.value }

		#expect(requestCount == 0)
		#expect(try Data(contentsOf: fixture.partial) == Data("ga".utf8))
	}

	@Test
	func unsafeManifestPathIsRejectedBeforeAnythingIsWritten() async throws {
		let fixture = try GameInstallerStreamingTests.makeFixture(
			body: Data("game".utf8), protocolClass: RollbackURLProtocol.self)
		defer { fixture.remove() }
		let escaping = ManifestFile(path: "../escape.dat", hash: fixture.item.hash, size: "4")
		await #expect(throws: (any Error).self) {
			try await withTestInstallDirectory(at: fixture.directory) { installDirectory in
				try await fixture.installer.download(
					escaping,
					source: fixture.source,
					baseURL: fixture.baseURL,
					installDirectory: installDirectory,
					counter: ProgressCounter(totalBytes: 4, totalFiles: 1),
					progress: { _ in }
				)
			}
		}

		let parent = fixture.directory.deletingLastPathComponent()
		#expect(!FileManager.default.fileExists(atPath: parent.appending(path: "escape.dat").path))
		#expect(
			!FileManager.default.fileExists(atPath: parent.appending(path: "escape.dat.part").path))
	}

	private static func download(
		_ fixture: InstallerFixture,
		baseline: Int,
		recorder: ProgressRecorder = ProgressRecorder()
	) async throws -> Int64 {
		try await withTestInstallDirectory(at: fixture.directory) { installDirectory in
			try await fixture.installer.download(
				fixture.item,
				source: fixture.source,
				baseURL: fixture.baseURL,
				installDirectory: installDirectory,
				counter: ProgressCounter(
					totalBytes: fixture.item.byteCount,
					totalFiles: 1,
					downloadedBytes: Int64(baseline)
				),
				progress: { update in await recorder.record(update) }
			)
		}
	}

	private static func writeMetadata(
		manifestHash: String,
		for fixture: InstallerFixture
	) async throws {
		try await withTestInstallDirectory(at: fixture.directory) { installDirectory in
			let staging = try installDirectory.stagingDirectory(
				named: AppConstants.Game.installerStagingDirectoryName
			)
			try fixture.installer.writeResumeMetadata(
				InstallerResumeMetadata(
					manifestHash: manifestHash,
					entityTag: "\"v0\"",
					lastModified: nil
				),
				to: fixture.installer.resumeMetadataFile(for: fixture.item.path, in: staging)
			)
		}
	}
}

/// Private to this suite so its handler cannot race the other suites' shared protocol.
private final class RollbackURLProtocol: URLProtocol, @unchecked Sendable {
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
