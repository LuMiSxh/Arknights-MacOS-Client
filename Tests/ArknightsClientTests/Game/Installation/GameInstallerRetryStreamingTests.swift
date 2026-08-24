// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct GameInstallerRetryStreamingTests {
	@Test
	func partialStreamFailureResetsRateBeforeResumingThePartialFile() async throws {
		let body = Data(repeating: 0x4A, count: 512 * 1_024)
		let partialNetworkBytes = 96 * 1_024
		let fixture = try GameInstallerStreamingTests.makeFixture(
			body: body,
			protocolClass: PartialStreamURLProtocol.self
		)
		defer { fixture.remove() }
		var requestCount = 0
		PartialStreamURLProtocol.handler = { request in
			requestCount += 1
			if requestCount == 1 {
				#expect(request.value(forHTTPHeaderField: "Range") == nil)
				return (
					GameInstallerStreamingTests.response(url: request.url!, status: 200),
					Data(body.prefix(partialNetworkBytes))
				)
			}
			#expect(
				request.value(forHTTPHeaderField: "Range")
					== "bytes=\(partialNetworkBytes)-"
			)
			return (
				GameInstallerStreamingTests.response(url: request.url!, status: 206),
				Data(body.dropFirst(partialNetworkBytes))
			)
		}
		defer { PartialStreamURLProtocol.handler = nil }
		let recorder = ProgressRecorder()

		_ = try await fixture.installer.install(
			configuration: fixture.configuration,
			region: .global,
			into: fixture.directory,
			progress: { update in await recorder.record(update) }
		)

		let updates = await recorder.updates()
		#expect(requestCount == 2)
		#expect(try Data(contentsOf: fixture.destination) == body)
		#expect(
			updates.contains {
				$0.networkDownloadedBytes == Int64(partialNetworkBytes)
					&& $0.transferRateBytesPerSecond == nil
			}
		)
		#expect(updates.last?.networkDownloadedBytes == Int64(body.count))
	}
}

private final class PartialStreamURLProtocol: URLProtocol, @unchecked Sendable {
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
		// A short, clean response is deterministic: URLSession does not implicitly replay
		// it, and the installer retries after validating the declared file size.
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}
}
