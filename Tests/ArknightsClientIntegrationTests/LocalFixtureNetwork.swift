// SPDX-License-Identifier: MPL-2.0

import Foundation

struct LocalFixtureNetwork: Sendable {
	let recorder: FixtureRequestRecorder

	private let configuration: Data
	private let branding: Data
	private let cdnConfiguration: Data
	private let manifestLocation: Data
	private let manifest: Data
	private let payload: Data

	init(recorder: FixtureRequestRecorder = FixtureRequestRecorder()) throws {
		self.recorder = recorder
		configuration = try Self.fixture(named: "game-configuration", extension: "json")
		branding = try Self.fixture(named: "branding", extension: "json")
		cdnConfiguration = try Self.fixture(named: "cdn-configuration", extension: "json")
		manifestLocation = try Self.fixture(named: "manifest-location", extension: "json")
		manifest = try Self.fixture(named: "manifest", extension: "json")
		payload = try Self.fixture(named: "fixture-payload", extension: "bin")
	}

	func response(for request: URLRequest) throws -> FixtureHTTPResponse {
		guard let url = request.url else { throw URLError(.badURL) }
		recorder.record(request)

		let data: Data
		switch (url.host, url.path) {
		case ("api-launcher-en.yo-star.com", "/api/launcher/game/config"):
			data = configuration
		case ("api-launcher-en.yo-star.com", "/api/launcher/base/config"):
			data = branding
		case ("api-launcher-en.yo-star.com", "/api/launcher/advanced/game/download/cdn"):
			data = cdnConfiguration
		case ("api-launcher-en.yo-star.com", "/api/launcher/game/config/json"):
			guard
				url.query() == "version=1.2.3&file_path=fixture-manifest.json"
			else { throw URLError(.unsupportedURL) }
			data = manifestLocation
		case ("fixtures.invalid", "/manifest.json"):
			data = manifest
		case ("local-cdn.invalid", "/fixture-source/Arknights.exe"):
			data = payload
		default:
			throw URLError(.unsupportedURL)
		}

		return FixtureHTTPResponse(url: url, data: data)
	}

	private static func fixture(named name: String, extension fileExtension: String) throws -> Data
	{
		guard
			let url = Bundle.module.url(
				forResource: name,
				withExtension: fileExtension,
				subdirectory: "Fixtures"
			)
		else { throw FixtureNetworkError.missingFixture("\(name).\(fileExtension)") }
		return try Data(contentsOf: url)
	}
}

struct FixtureHTTPResponse: Sendable {
	let response: HTTPURLResponse
	let data: Data

	init(url: URL, data: Data) {
		guard
			let response = HTTPURLResponse(
				url: url,
				statusCode: 200,
				httpVersion: "HTTP/1.1",
				headerFields: ["Content-Length": String(data.count)]
			)
		else { fatalError("Could not create an HTTP fixture response for \(url)") }
		self.response = response
		self.data = data
	}
}

final class FixtureRequestRecorder: @unchecked Sendable {
	private let lock = NSLock()
	private var requests: [URLRequest] = []

	func record(_ request: URLRequest) {
		lock.withLock {
			requests.append(request)
		}
	}

	func recordedRequests() -> [URLRequest] {
		lock.withLock { requests }
	}
}

private enum FixtureNetworkError: Error {
	case missingFixture(String)
}

final class LocalFixtureURLProtocol: URLProtocol, @unchecked Sendable {
	nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> FixtureHTTPResponse)?

	override class func canInit(with request: URLRequest) -> Bool { true }

	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		do {
			guard let result = try Self.handler?(request) else {
				throw URLError(.resourceUnavailable)
			}
			client?.urlProtocol(self, didReceive: result.response, cacheStoragePolicy: .notAllowed)
			client?.urlProtocol(self, didLoad: result.data)
			client?.urlProtocolDidFinishLoading(self)
		} catch {
			client?.urlProtocol(self, didFailWithError: error)
		}
	}

	override func stopLoading() {}
}
