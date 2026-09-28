// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct GameInstallerVerificationTests {
	@Test
	func repairReportsVerificationProgressBeforeReusingIntactFiles() async throws {
		let body = Data(repeating: 0x3C, count: 256 * 1_024)
		let fixture = try GameInstallerStreamingTests.makeFixture(body: body)
		defer { fixture.remove() }
		try body.write(to: fixture.destination)
		StreamingURLProtocol.handler = nil
		let recorder = ProgressRecorder()

		let result = try await fixture.installer.install(
			configuration: fixture.configuration,
			region: .global,
			into: fixture.directory,
			verifyAllExistingFiles: true,
			progress: { update in await recorder.record(update) }
		)

		let updates = await recorder.updates()
		#expect(result.downloadedFiles == 0)
		#expect(updates.allSatisfy { $0.isVerifying })
		#expect(updates.last?.downloadedBytes == Int64(body.count))
		#expect(updates.last?.totalBytes == Int64(body.count))
		#expect(updates.last?.completedFiles == 1)
		#expect(updates.map(\.sequence) == updates.map(\.sequence).sorted())
	}

	@Test
	func downloadProgressContinuesAfterTheVerificationSequence() async throws {
		let body = Data(repeating: 0x7E, count: 128 * 1_024)
		let fixture = try GameInstallerStreamingTests.makeFixture(body: body)
		defer { fixture.remove() }
		try Data(repeating: 0x00, count: body.count).write(to: fixture.destination)
		StreamingURLProtocol.handler = { request in
			(GameInstallerStreamingTests.response(url: request.url!, status: 200), body)
		}
		defer { StreamingURLProtocol.handler = nil }
		let recorder = ProgressRecorder()

		_ = try await fixture.installer.install(
			configuration: fixture.configuration,
			region: .global,
			into: fixture.directory,
			verifyAllExistingFiles: true,
			progress: { update in await recorder.record(update) }
		)

		let updates = await recorder.updates()
		let lastVerification = try #require(updates.last { $0.isVerifying })
		let firstDownload = try #require(updates.first { !$0.isVerifying })
		#expect(firstDownload.sequence > lastVerification.sequence)
		#expect(try Data(contentsOf: fixture.destination) == body)
	}

	@Test(arguments: ["123", "0123456789abcdef0123456789abcdef"])
	func checksumStopsWhenItsTaskIsCancelled(expected: String) async throws {
		let url = FileManager.default.temporaryDirectory.appending(
			path: "GameInstallerVerificationTests-\(UUID().uuidString)")
		try Data(repeating: 0x11, count: 64 * 1_024).write(to: url)
		defer { try? FileManager.default.removeItem(at: url) }

		let task = Task {
			while !Task.isCancelled { await Task.yield() }
			return try ManifestChecksum.checksum(of: url, expected: expected)
		}
		task.cancel()

		await #expect(throws: CancellationError.self) { try await task.value }
	}
}

@Test
func verificationProgressFillsTheOutlineWithItsOwnFraction() {
	let verifying = DownloadProgress(
		downloadedBytes: 25,
		totalBytes: 100,
		completedFiles: 1,
		totalFiles: 4,
		currentFile: "client.dat",
		isVerifying: true
	)

	#expect(
		LauncherDownloadProgressPresentation.outlineFraction(
			for: verifying,
			status: .verifyingInstallation,
			hasPartialDownload: false,
			hasFailure: false
		) == 0.25
	)
	#expect(
		LauncherDownloadProgressPresentation.outlineFraction(
			for: nil,
			status: .verifyingInstallation,
			hasPartialDownload: false,
			hasFailure: false
		) == 1
	)
	#expect(
		LauncherDownloadProgressPresentation.title(for: verifying, isPaused: false)
			== "Verifying · 25%"
	)
}
