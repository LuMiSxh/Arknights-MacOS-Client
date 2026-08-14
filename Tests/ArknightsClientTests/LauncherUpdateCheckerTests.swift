// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct LauncherUpdateCheckerTests {
	@Test
	func latestReleaseDecodesGitHubResponseAndSendsExpectedHeaders() async throws {
		let endpoint = URL(
			string: "https://api.github.test/repos/example/arknights/releases/latest")!
		let session = makeMockSession()
		let receivedRequest = LockedValue<URLRequest?>(nil)

		MockURLProtocol.handler = { request in
			receivedRequest.set(request)
			return .success(
				(
					HTTPURLResponse(
						url: endpoint, statusCode: 200, httpVersion: nil, headerFields: nil)!,
					Data(
						#"""
						{
						  "tag_name": "v1.4.0-rc.1",
						  "html_url": "https://github.com/example/arknights/releases/tag/v1.4.0-rc.1",
						  "draft": false,
						  "prerelease": true
						}
						"""#.utf8
					)
				)
			)
		}
		defer { MockURLProtocol.handler = nil }

		let release = try await LauncherUpdateChecker(session: session).latestRelease(
			from: endpoint)

		#expect(release.tagName == "v1.4.0-rc.1")
		#expect(release.version == "1.4.0-rc.1")
		#expect(release.isPrerelease)
		#expect(
			receivedRequest.value?.value(forHTTPHeaderField: "Accept")
				== "application/vnd.github+json")
		#expect(receivedRequest.value?.value(forHTTPHeaderField: "User-Agent") == "ArknightsClient")
	}

	@Test
	func latestReleaseRejectsNonSuccessHTTPResponses() async {
		let endpoint = URL(
			string: "https://api.github.test/repos/example/arknights/releases/latest")!
		let session = makeMockSession()
		MockURLProtocol.handler = { _ in
			.success(
				(
					HTTPURLResponse(
						url: endpoint, statusCode: 503, httpVersion: nil, headerFields: nil)!,
					Data()
				))
		}
		defer { MockURLProtocol.handler = nil }

		await #expect(throws: LauncherError.self) {
			try await LauncherUpdateChecker(session: session).latestRelease(from: endpoint)
		}
	}

	@Test(arguments: [
		("v1.2.4", "1.2.3", true),
		("1.2.3", "v1.2.3-rc.1", true),
		("v1.2.3-rc.2", "1.2.3-rc.1", true),
		("v1.2.3-rc.10", "1.2.3-rc.2", true),
		("v1.2.3-alpha", "1.2.3-alpha.1", false),
		("v1.2.3+build.7", "1.2.3+build.6", false),
		("V1.2.4", "v1.2.3", true),
		("999999999999999999999999", "1.2.3", false),
		("1.2.3+", "1.2.2", false),
		("v2", "1.9.9", true),
		("v1.2.3", "not-a-version", false),
	])
	func semanticVersionComparison(candidate: String, current: String, expected: Bool) {
		#expect(LauncherUpdateChecker().isNewer(candidate, than: current) == expected)
	}
}

private func makeMockSession() -> URLSession {
	let configuration = URLSessionConfiguration.ephemeral
	configuration.protocolClasses = [MockURLProtocol.self]
	return URLSession(configuration: configuration)
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
	typealias Result = Swift.Result<(HTTPURLResponse, Data), Error>

	nonisolated(unsafe) static var handler: ((URLRequest) -> Result)?

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		guard let handler = Self.handler else {
			client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
			return
		}

		switch handler(request) {
		case .success(let response):
			client?.urlProtocol(self, didReceive: response.0, cacheStoragePolicy: .notAllowed)
			client?.urlProtocol(self, didLoad: response.1)
			client?.urlProtocolDidFinishLoading(self)
		case .failure(let error):
			client?.urlProtocol(self, didFailWithError: error)
		}
	}

	override func stopLoading() {}
}

private final class LockedValue<Value>: @unchecked Sendable {
	private let lock = NSLock()
	private var storage: Value

	init(_ value: Value) {
		storage = value
	}

	var value: Value {
		lock.withLock { storage }
	}

	func set(_ value: Value) {
		lock.withLock { storage = value }
	}
}
