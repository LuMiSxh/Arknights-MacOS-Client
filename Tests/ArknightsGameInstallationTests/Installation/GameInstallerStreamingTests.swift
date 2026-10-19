// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation

@Suite(.serialized)
struct GameInstallerStreamingTests {
	/// The server honors the range: only the missing tail is transferred.
	@Test
	func installerResumesAPartialFileFromTheServedRange() async throws {
		let body = Data(repeating: 0xA5, count: 512 * 1_024)
		let partialSize = 96 * 1_024
		let fixture = try InstallerFixture.make(body: body)
		defer { fixture.remove() }
		try body.prefix(partialSize).write(to: fixture.partial)
		fixture.route.handler = { request in
			#expect(request.value(forHTTPHeaderField: "Range") == "bytes=98304-")
			return (
				makeHTTPResponse(
					url: request.url!,
					status: 206,
					headers: ["Content-Range": "bytes 98304-524287/524288"]
				),
				Data(body.dropFirst(partialSize))
			)
		}
		let recorder = ProgressRecorder()

		let result = try await fixture.install(progress: { update in
			await recorder.record(update)
		})

		let updates = await recorder.updates()
		#expect(try Data(contentsOf: fixture.destination) == body)
		#expect(result.downloadedBytes == Int64(body.count))
		#expect(updates.first?.downloadedBytes == Int64(partialSize))
		#expect(updates.first?.networkDownloadedBytes == 0)
		#expect(updates.last?.downloadedBytes == Int64(body.count))
		#expect(updates.last?.networkDownloadedBytes == Int64(body.count - partialSize))
	}

	enum ResumeBlocker: CaseIterable {
		case serverIgnoresRange
		case staleMetadata
	}

	/// A partial restarts from zero when its range is ignored or its resume metadata is stale.
	@Test(arguments: ResumeBlocker.allCases)
	func partialRestartsFromZeroWhenItCannotBeResumed(blocker: ResumeBlocker) async throws {
		let body = Data("game".utf8)
		let fixture = try InstallerFixture.make(body: body)
		defer { fixture.remove() }
		try Data("ga".utf8).write(to: fixture.partial)
		if blocker == .staleMetadata {
			try await fixture.writeResumeMetadata(manifestHash: "0")
		}
		let expectedRange = blocker == .serverIgnoresRange ? "bytes=2-" : nil
		fixture.route.handler = { request in
			#expect(request.value(forHTTPHeaderField: "Range") == expectedRange)
			return (makeHTTPResponse(url: request.url!, status: 200), body)
		}
		let recorder = ProgressRecorder()

		let networkBytes = try await fixture.download(baseline: 2, recorder: recorder)

		#expect(networkBytes == Int64(body.count))
		#expect(try Data(contentsOf: fixture.destination) == body)
		#expect(await recorder.updates().contains { $0.downloadedBytes == 0 })
	}

	/// The entity changes between the first and the resumed request: restart without a range.
	@Test
	func installerRestartsWithoutARangeWhenTheEntityChanges() async throws {
		let body = Data("game".utf8)
		let fixture = try InstallerFixture.make(body: body)
		defer { fixture.remove() }
		var requestCount = 0
		fixture.route.handler = { request in
			requestCount += 1
			switch requestCount {
			case 1:
				#expect(request.value(forHTTPHeaderField: "Range") == nil)
				return (
					makeHTTPResponse(url: request.url!, status: 200, headers: ["ETag": "\"v1\""]),
					Data("ga".utf8)
				)
			case 2:
				#expect(request.value(forHTTPHeaderField: "Range") == "bytes=2-")
				#expect(request.value(forHTTPHeaderField: "If-Range") == "\"v1\"")
				return (
					makeHTTPResponse(
						url: request.url!,
						status: 206,
						headers: ["Content-Range": "bytes 2-3/4", "ETag": "\"v2\""]
					),
					Data("me".utf8)
				)
			default:
				#expect(request.value(forHTTPHeaderField: "Range") == nil)
				return (
					makeHTTPResponse(url: request.url!, status: 200, headers: ["ETag": "\"v2\""]),
					body
				)
			}
		}

		_ = try await fixture.install(progress: { _ in })

		#expect(requestCount == 3)
		#expect(try Data(contentsOf: fixture.destination) == body)
	}

	/// A complete partial is promoted without a network request.
	@Test
	func completePartialIsPromotedWithoutARequest() async throws {
		let body = Data("game".utf8)
		let fixture = try InstallerFixture.make(body: body)
		defer { fixture.remove() }
		try body.write(to: fixture.partial)
		var requestCount = 0
		fixture.route.handler = { request in
			requestCount += 1
			return (makeHTTPResponse(url: request.url!, status: 200), body)
		}

		let networkBytes = try await fixture.download(baseline: body.count)

		#expect(networkBytes == 0)
		#expect(requestCount == 0)
		#expect(try Data(contentsOf: fixture.destination) == body)
		#expect(!FileManager.default.fileExists(atPath: fixture.partial.path))
	}

	/// Official manifests prefix paths with a slash; the request URL joins them cleanly.
	@Test
	func installerJoinsSlashPrefixedManifestPathsIntoTheRequestURL() async throws {
		let body = Data("game".utf8)
		let fixture = try InstallerFixture.make(
			body: body,
			source: "/Arknights_JP-36.7.23-game",
			relativePath: "/bin/Arknights.exe"
		)
		defer { fixture.remove() }
		try FileManager.default.removeItem(at: fixture.destination.deletingLastPathComponent())
		fixture.route.handler = { request in
			#expect(
				request.url?.absoluteString
					== "https://download.yo-star.com/Arknights_JP-36.7.23-game/bin/Arknights.exe"
			)
			return (makeHTTPResponse(url: request.url!, status: 200), body)
		}

		_ = try await fixture.install(region: .japan)

		#expect(try Data(contentsOf: fixture.destination) == body)
	}

	/// A rejected answer keeps the resumable partial. A rejected range also keeps the old destination.
	@Test
	func rejectedAnswersKeepTheResumablePartial() async throws {
		do {
			let fixture = try InstallerFixture.make(body: Data("game".utf8))
			defer { fixture.remove() }
			let previous = Data("old!".utf8)
			try previous.write(to: fixture.destination)
			try Data("ga".utf8).write(to: fixture.partial)
			fixture.route.handler = { request in
				#expect(request.value(forHTTPHeaderField: "Range") == "bytes=2-")
				return (
					makeHTTPResponse(
						url: request.url!,
						status: 206,
						headers: ["Content-Range": "bytes 1-3/4"]
					),
					Data("me".utf8)
				)
			}

			await #expect(throws: (any Error).self) {
				_ = try await fixture.download(baseline: 2)
			}

			#expect(try Data(contentsOf: fixture.destination) == previous)
			#expect(try Data(contentsOf: fixture.partial) == Data("ga".utf8))
		}

		do {
			let fixture = try InstallerFixture.make(body: Data("game".utf8))
			defer { fixture.remove() }
			try Data("ga".utf8).write(to: fixture.partial)
			fixture.route.handler = { request in
				(makeHTTPResponse(url: request.url!, status: 404), Data())
			}

			do {
				_ = try await fixture.download(baseline: 2)
				Issue.record("Expected the 404 response to be rejected")
			} catch InstallerError.invalidDownloadResponse(let status, let path) {
				#expect(status == 404)
				#expect(path == fixture.item.path)
			} catch {
				Issue.record("Unexpected installer error: \(error)")
			}

			#expect(try Data(contentsOf: fixture.partial) == Data("ga".utf8))
			#expect(!FileManager.default.fileExists(atPath: fixture.destination.path))
		}
	}

	/// A body that does not match its declared range truncates back to the resume offset.
	@Test(arguments: zip(["bytes 1-2/4", "bytes 1-3/4"], ["ome", "om"]))
	func bodyThatDoesNotMatchItsRangeTruncatesToTheResumeOffset(
		contentRange: String,
		payload: String
	) async throws {
		let fixture = try InstallerFixture.make(body: Data("game".utf8))
		defer { fixture.remove() }
		try Data("g".utf8).write(to: fixture.partial)
		fixture.route.handler = { request in
			#expect(request.value(forHTTPHeaderField: "Range") == "bytes=1-")
			return (
				makeHTTPResponse(
					url: request.url!,
					status: 206,
					headers: ["Content-Range": contentRange]
				),
				Data(payload.utf8)
			)
		}
		let recorder = ProgressRecorder()

		await #expect(throws: LauncherError.self) {
			_ = try await fixture.download(baseline: 1, recorder: recorder)
		}

		#expect(try Data(contentsOf: fixture.partial) == Data("g".utf8))
		let last = await recorder.updates().last
		#expect(last?.downloadedBytes == 1)
		#expect(last?.networkDownloadedBytes == 0)
	}

	@Test
	func installerStopsWritingWhenAResponseExceedsTheManifestSize() async throws {
		let body = Data("game".utf8)
		let fixture = try InstallerFixture.make(body: body)
		defer { fixture.remove() }
		fixture.route.handler = { request in
			(
				makeHTTPResponse(url: request.url!, status: 200),
				body + Data(repeating: 0xFF, count: 64 * 1_024)
			)
		}
		do {
			_ = try await fixture.download(baseline: 0)
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
}
