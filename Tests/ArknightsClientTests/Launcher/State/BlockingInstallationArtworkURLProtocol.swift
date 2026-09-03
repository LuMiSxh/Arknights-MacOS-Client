// SPDX-License-Identifier: MPL-2.0

import Foundation

final class BlockingInstallationArtworkURLProtocol: URLProtocol, @unchecked Sendable {
	static let imageData = Data(
		base64Encoded:
			"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zf9sAAAAASUVORK5CYII="
	)!
	private static let lock = NSLock()
	nonisolated(unsafe) static var artworkRequestStarted = false
	nonisolated(unsafe) static var artworkGate = DispatchSemaphore(value: 0)

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		if request.url?.host == "example.com" {
			let gate = Self.lock.withLock {
				Self.artworkRequestStarted = true
				return Self.artworkGate
			}
			gate.wait()
		}
		let response = HTTPURLResponse(
			url: request.url!,
			statusCode: 200,
			httpVersion: nil,
			headerFields: nil
		)!
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		client?.urlProtocol(self, didLoad: Self.imageData)
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}

	static func releaseArtwork() {
		lock.withLock { _ = artworkGate.signal() }
	}

	static func reset() {
		let gate = lock.withLock {
			artworkRequestStarted = false
			return artworkGate
		}
		while gate.wait(timeout: .now()) == .success {}
	}

	static var isArtworkRequestStarted: Bool {
		lock.withLock { artworkRequestStarted }
	}
}
