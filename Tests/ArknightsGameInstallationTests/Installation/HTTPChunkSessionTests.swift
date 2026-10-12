// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation
@testable import ArknightsInfrastructure

@Suite(.serialized)
struct HTTPChunkSessionTests {
	/// Reaching the ceiling must delay bytes, never drop them.
	@Test
	func chunkSessionDeliversEveryByteWhenTheBufferCeilingIsReached() async throws {
		let route = StubURLProtocol.Route(chunkSize: 4_096)
		let configuration = URLSessionConfiguration.ephemeral
		route.configure(configuration)
		let session = HTTPChunkSession(configuration: configuration, maximumBufferedBytes: 4_096)
		let url = URL(string: "https://download.test/game.bin")!
		let expected = Data(repeating: 0x33, count: 64 * 1_024)
		route.handler = { _ in
			(
				HTTPURLResponse(
					url: url,
					statusCode: 206,
					httpVersion: "HTTP/1.1",
					headerFields: ["Content-Length": String(expected.count)]
				)!,
				expected
			)
		}

		let stream = session.stream(for: URLRequest(url: url))
		var received = Data()
		for try await event in stream.events {
			guard case .data(let chunk) = event else { continue }
			received.append(chunk)
			stream.acknowledge(chunk.count)
		}

		#expect(received == expected)
	}

	@Test
	func chunkSessionRejectsAStreamRedirectOutsideItsPolicy() async throws {
		let route = StubURLProtocol.Route()
		let configuration = URLSessionConfiguration.ephemeral
		route.configure(configuration)
		let session = HTTPChunkSession(
			configuration: configuration,
			maximumBufferedBytes: AppConstants.Network.maximumBufferedStreamBytes
		)
		let sourceURL = URL(string: "https://download.test/game.bin")!
		route.redirectURL = URL(string: "https://evil.test/game.bin")!

		let stream = session.stream(
			for: URLRequest(url: sourceURL),
			redirectValidator: { $0.host == "download.test" }
		)
		var rejected = false
		do {
			for try await _ in stream.events {}
		} catch HTTPTransportError.redirectRejected(let rejectedURL) {
			rejected = rejectedURL.host == "evil.test"
		}

		#expect(rejected)
	}
}
