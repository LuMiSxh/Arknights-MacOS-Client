// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import ArknightsTestSupport
import Darwin
import Foundation
import Testing

@testable import ArknightsGameInstallation

@Suite(.serialized)
struct GameInstallerStreamingTests {
	/// One table of server answers to a `.part` file: every row must end with the right bytes, and
	/// a rejected answer must leave the resumable partial and the previous destination intact.
	@Test
	func installerResumesAPartialFileWithBufferedChunks() async throws {
		// The server honors the range: only the missing tail is transferred.
		do {
			let body = Data(repeating: 0xA5, count: 512 * 1_024)
			let partialSize = 96 * 1_024
			let fixture = try Self.makeFixture(body: body)
			defer { fixture.remove() }
			try body.prefix(partialSize).write(to: fixture.partial)
			fixture.route.handler = { request in
				#expect(request.value(forHTTPHeaderField: "Range") == "bytes=98304-")
				return (
					Self.response(
						url: request.url!,
						status: 206,
						headers: ["Content-Range": "bytes 98304-524287/524288"]
					),
					Data(body.dropFirst(partialSize))
				)
			}
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

		// The server ignores the range: the partial restarts from zero.
		do {
			let body = Data(repeating: 0x5A, count: 384 * 1_024)
			let fixture = try Self.makeFixture(body: body)
			defer { fixture.remove() }
			try Data(repeating: 0xFF, count: 64 * 1_024).write(to: fixture.partial)
			fixture.route.handler = { request in
				#expect(request.value(forHTTPHeaderField: "Range") == "bytes=65536-")
				return (Self.response(url: request.url!, status: 200), body)
			}
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

		// The entity changes between the first and the resumed request: restart without a range.
		do {
			let body = Data("game".utf8)
			let fixture = try Self.makeFixture(body: body)
			defer { fixture.remove() }
			var requestCount = 0
			fixture.route.handler = { request in
				requestCount += 1
				switch requestCount {
				case 1:
					#expect(request.value(forHTTPHeaderField: "Range") == nil)
					return (
						Self.response(url: request.url!, status: 200, headers: ["ETag": "\"v1\""]),
						Data("ga".utf8)
					)
				case 2:
					#expect(request.value(forHTTPHeaderField: "Range") == "bytes=2-")
					#expect(request.value(forHTTPHeaderField: "If-Range") == "\"v1\"")
					return (
						Self.response(
							url: request.url!,
							status: 206,
							headers: ["Content-Range": "bytes 2-3/4", "ETag": "\"v2\""]
						),
						Data("me".utf8)
					)
				default:
					#expect(request.value(forHTTPHeaderField: "Range") == nil)
					return (
						Self.response(url: request.url!, status: 200, headers: ["ETag": "\"v2\""]),
						body
					)
				}
			}

			_ = try await fixture.installer.install(
				configuration: fixture.configuration,
				region: .global,
				into: fixture.directory,
				progress: { _ in }
			)

			#expect(requestCount == 3)
			#expect(try Data(contentsOf: fixture.destination) == body)
		}

		// A wrong Content-Range start is rejected and keeps the partial and the old destination.
		do {
			let fixture = try Self.makeFixture(body: Data("game".utf8))
			defer { fixture.remove() }
			let previous = Data("old!".utf8)
			try previous.write(to: fixture.destination)
			try Data("ga".utf8).write(to: fixture.partial)
			fixture.route.handler = { request in
				#expect(request.value(forHTTPHeaderField: "Range") == "bytes=2-")
				return (
					Self.response(
						url: request.url!, status: 206, headers: ["Content-Range": "bytes 1-3/4"]),
					Data("me".utf8)
				)
			}

			await #expect(throws: (any Error).self) {
				_ = try await Self.download(fixture, baseline: 2)
			}

			#expect(try Data(contentsOf: fixture.destination) == previous)
			#expect(try Data(contentsOf: fixture.partial) == Data("ga".utf8))
		}

		// A body that does not match its declared range truncates back to the resume offset.
		for (contentRange, payload) in [("bytes 1-2/4", "ome"), ("bytes 1-3/4", "om")] {
			let fixture = try Self.makeFixture(body: Data("game".utf8))
			defer { fixture.remove() }
			try Data("g".utf8).write(to: fixture.partial)
			fixture.route.handler = { request in
				#expect(request.value(forHTTPHeaderField: "Range") == "bytes=1-")
				return (
					Self.response(
						url: request.url!, status: 206, headers: ["Content-Range": contentRange]),
					Data(payload.utf8)
				)
			}
			let recorder = ProgressRecorder()

			await #expect(throws: LauncherError.self) {
				_ = try await Self.download(fixture, baseline: 1, recorder: recorder)
			}

			#expect(try Data(contentsOf: fixture.partial) == Data("g".utf8))
			let last = await recorder.updates().last
			#expect(last?.downloadedBytes == 1)
			#expect(last?.networkDownloadedBytes == 0)
		}

		// Resume metadata from another manifest revision is stale: restart from zero.
		do {
			let body = Data("game".utf8)
			let fixture = try Self.makeFixture(body: body)
			defer { fixture.remove() }
			try Data("ga".utf8).write(to: fixture.partial)
			try await Self.writeMetadata(manifestHash: "0", for: fixture)
			fixture.route.handler = { request in
				#expect(request.value(forHTTPHeaderField: "Range") == nil)
				return (Self.response(url: request.url!, status: 200), body)
			}
			let recorder = ProgressRecorder()

			let networkBytes = try await Self.download(fixture, baseline: 2, recorder: recorder)

			#expect(networkBytes == Int64(body.count))
			#expect(try Data(contentsOf: fixture.destination) == body)
			#expect(await recorder.updates().contains { $0.downloadedBytes == 0 })
		}

		// A complete partial is promoted without a network request.
		do {
			let body = Data("game".utf8)
			let fixture = try Self.makeFixture(body: body)
			defer { fixture.remove() }
			try body.write(to: fixture.partial)
			var requestCount = 0
			fixture.route.handler = { request in
				requestCount += 1
				return (Self.response(url: request.url!, status: 200), body)
			}

			let networkBytes = try await Self.download(fixture, baseline: body.count)

			#expect(networkBytes == 0)
			#expect(requestCount == 0)
			#expect(try Data(contentsOf: fixture.destination) == body)
			#expect(!FileManager.default.fileExists(atPath: fixture.partial.path))
		}

		// Official manifests prefix paths with a slash; the request URL joins them cleanly.
		do {
			let body = Data("game".utf8)
			let fixture = try Self.makeFixture(
				body: body, source: "/Arknights_JP-36.7.23-game", relativePath: "/bin/Arknights.exe"
			)
			defer { fixture.remove() }
			try FileManager.default.removeItem(at: fixture.destination.deletingLastPathComponent())
			fixture.route.handler = { request in
				#expect(
					request.url?.absoluteString
						== "https://download.yo-star.com/Arknights_JP-36.7.23-game/bin/Arknights.exe"
				)
				return (Self.response(url: request.url!, status: 200), body)
			}

			_ = try await fixture.installer.install(
				configuration: fixture.configuration,
				region: .japan,
				into: fixture.directory,
				progress: { _ in }
			)

			#expect(try Data(contentsOf: fixture.destination) == body)
		}
	}

	@Test
	func installerStopsWritingWhenAResponseExceedsTheManifestSize() async throws {
		let body = Data("game".utf8)
		let fixture = try Self.makeFixture(body: body)
		defer { fixture.remove() }
		fixture.route.handler = { request in
			return (
				Self.response(url: request.url!, status: 200),
				body + Data(repeating: 0xFF, count: 64 * 1_024)
			)
		}
		do {
			_ = try await withTestInstallDirectory(at: fixture.directory) { installDirectory in
				try await fixture.installer.download(
					fixture.item,
					source: fixture.source,
					baseURL: fixture.baseURL,
					installDirectory: installDirectory,
					counter: ProgressCounter(
						totalBytes: fixture.item.byteCount,
						totalFiles: 1
					),
					progress: { _ in }
				)
			}
			Issue.record("Expected the oversized response to be rejected")
		} catch InstallerError.downloadedSizeMismatch(_, let expected, let actual) {
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

	static func download(
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

	static func writeMetadata(manifestHash: String, for fixture: InstallerFixture) async throws {
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

	static func makeFixture(
		body: Data,
		source: String = "payload",
		relativePath: String = "bin/game.dat",
		protocolClass: URLProtocol.Type? = nil
	) throws -> InstallerFixture {
		let baseURL = URL(string: "https://download.yo-star.com")!
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
		let route = StubURLProtocol.Route(chunkSize: 32 * 1_024)
		let sessionConfiguration = URLSessionConfiguration.ephemeral
		if let protocolClass {
			sessionConfiguration.protocolClasses = [protocolClass]
		} else {
			route.configure(sessionConfiguration)
		}
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
			),
			route: route
		)
	}

	static func response(
		url: URL,
		status: Int,
		headers: [String: String] = [:]
	) -> HTTPURLResponse {
		HTTPURLResponse(
			url: url,
			statusCode: status,
			httpVersion: "HTTP/1.1",
			headerFields: headers
		)!
	}
}
