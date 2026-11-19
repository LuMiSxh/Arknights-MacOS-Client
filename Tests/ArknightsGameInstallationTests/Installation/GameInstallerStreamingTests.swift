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
			#expect(actual == Int64(body.count) + 64 * 1_024)
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
