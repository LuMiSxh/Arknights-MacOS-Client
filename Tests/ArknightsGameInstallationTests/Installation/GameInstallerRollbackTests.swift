// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsGameInstallation

/// Pins how a single download attempt reconciles its `.part` file and progress with the
/// server's answer, independent of how `GameInstaller.download` is structured internally.
@Suite(.serialized)
struct GameInstallerRollbackTests {
	@Test
	func checksumMismatchEmptiesThePartialAndRemovesItsCountedBytes() async throws {
		let fixture = try GameInstallerStreamingTests.makeFixture(
			body: Data("game".utf8))
		defer { fixture.remove() }
		try Data("ga".utf8).write(to: fixture.partial)
		fixture.route.handler = { request in
			(
				GameInstallerStreamingTests.response(
					url: request.url!,
					status: 206,
					headers: ["Content-Range": "bytes 2-3/4"]
				),
				Data("xx".utf8)
			)
		}
		let recorder = ProgressRecorder()

		do {
			_ = try await Self.download(fixture, baseline: 2, recorder: recorder)
			Issue.record("Expected the corrupted file to fail verification")
		} catch InstallerError.checksumMismatch(let path, _, _) {
			#expect(path == fixture.item.path)
		} catch {
			Issue.record("Unexpected installer error: \(error)")
		}

		#expect(try Data(contentsOf: fixture.partial).isEmpty)
		#expect(!FileManager.default.fileExists(atPath: fixture.destination.path))
		let last = await recorder.updates().last
		#expect(last?.downloadedBytes == 0)
		#expect(last?.networkDownloadedBytes == 0)
		#expect(last?.transferRateBytesPerSecond == nil)
	}

	@Test
	func cancelledDownloadLeavesTheResumablePartialUntouched() async throws {
		let fixture = try GameInstallerStreamingTests.makeFixture(
			body: Data("game".utf8))
		defer { fixture.remove() }
		try Data("ga".utf8).write(to: fixture.partial)
		var requestCount = 0
		fixture.route.handler = { request in
			requestCount += 1
			return (GameInstallerStreamingTests.response(url: request.url!, status: 200), Data())
		}

		let task = Task {
			withUnsafeCurrentTask { $0?.cancel() }
			return try await Self.download(fixture, baseline: 2)
		}
		await #expect(throws: CancellationError.self) { try await task.value }

		#expect(requestCount == 0)
		#expect(try Data(contentsOf: fixture.partial) == Data("ga".utf8))

		// An unsuccessful status keeps the resumable partial too.
		fixture.route.handler = { request in
			(GameInstallerStreamingTests.response(url: request.url!, status: 404), Data())
		}
		do {
			_ = try await Self.download(fixture, baseline: 2)
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

	private static func download(
		_ fixture: InstallerFixture,
		baseline: Int,
		recorder: ProgressRecorder = ProgressRecorder()
	) async throws -> Int64 {
		try await GameInstallerStreamingTests.download(
			fixture, baseline: baseline, recorder: recorder)
	}
}
