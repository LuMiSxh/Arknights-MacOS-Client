// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func chunkSessionStreamsResponseAndBodyWithoutPerByteIteration() async throws {
	let configuration = URLSessionConfiguration.ephemeral
	configuration.protocolClasses = [ChunkedURLProtocol.self]
	let session = HTTPChunkSession(configuration: configuration)
	let url = URL(string: "https://download.test/game.bin")!
	let expected = Data(repeating: 0xA5, count: 512 * 1_024)
	ChunkedURLProtocol.response = HTTPURLResponse(
		url: url,
		statusCode: 206,
		httpVersion: "HTTP/1.1",
		headerFields: ["Content-Length": String(expected.count)]
	)!
	ChunkedURLProtocol.chunks = [
		expected.subdata(in: 0..<(128 * 1_024)),
		expected.subdata(in: (128 * 1_024)..<(384 * 1_024)),
		expected.subdata(in: (384 * 1_024)..<expected.count),
	]
	defer { ChunkedURLProtocol.reset() }

	let stream = session.stream(for: URLRequest(url: url))
	var status: Int?
	var received = Data()
	for try await event in stream.events {
		switch event {
		case .response(let response):
			status = response.statusCode
		case .data(let data):
			received.append(data)
		}
	}

	#expect(status == 206)
	#expect(received == expected)
}

private final class ChunkedURLProtocol: URLProtocol, @unchecked Sendable {
	nonisolated(unsafe) static var response: HTTPURLResponse?
	nonisolated(unsafe) static var chunks: [Data] = []

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		guard let response = Self.response else {
			client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
			return
		}
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		for chunk in Self.chunks {
			client?.urlProtocol(self, didLoad: chunk)
		}
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}

	static func reset() {
		response = nil
		chunks = []
	}
}
