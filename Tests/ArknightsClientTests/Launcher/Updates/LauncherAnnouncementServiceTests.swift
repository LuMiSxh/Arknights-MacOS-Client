// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)

struct LauncherAnnouncementServiceTests {
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
		guard let candidate = SemanticVersion(candidate), let current = SemanticVersion(current)
		else {
			#expect(!expected)
			return
		}
		#expect((candidate > current) == expected)
	}

	@Test
	func feedDecodesMarkdownAndSendsRawGitHubHeader() async throws {
		let endpoint = URL(string: "https://api.github.test/repos/example/contents/feed.json")!
		let session = makeMockSession()
		let receivedRequest = LockedValue<URLRequest?>(nil)
		MockURLProtocol.setHandler { request in
			receivedRequest.set(request)
			return .success(
				(
					HTTPURLResponse(
						url: endpoint, statusCode: 200, httpVersion: nil, headerFields: nil)!,
					Data(
						#"{"schemaVersion":1,"announcements":[{"id":"feedback","enabled":true,"title":"Feedback","body":"**Tell us** what you think.","actionTitle":"Open Issues","actionURL":"https://github.com/example/issues","minimumVersion":"0.2.0","maximumVersion":null,"startsAt":null,"endsAt":null}]}"#
							.utf8
					)
				)
			)
		}
		defer { MockURLProtocol.reset() }

		let announcements = try await LauncherAnnouncementService(session: session)
			.announcements(from: endpoint)

		#expect(announcements.first?.body == "**Tell us** what you think.")
		#expect(
			receivedRequest.value?.value(forHTTPHeaderField: "Accept")
				== "application/vnd.github.raw+json"
		)
	}

	@Test
	func oversizedFeedMapsToFeatureError() async {
		let endpoint = URL(string: "https://api.github.test/repos/example/contents/feed.json")!
		let session = makeMockSession()
		MockURLProtocol.setHandler { request in
			.success(
				(
					HTTPURLResponse(
						url: endpoint, statusCode: 200, httpVersion: nil, headerFields: nil)!,
					Data(repeating: 0, count: AppConstants.Network.announcementFeedMaximumBytes + 1)
				)
			)
		}
		defer { MockURLProtocol.reset() }

		do {
			_ = try await LauncherAnnouncementService(session: session)
				.announcements(from: endpoint)
			Issue.record("Expected oversized feed to fail")
		} catch let error as LauncherError {
			guard case .remoteContentTooLarge(endpoint, _) = error else {
				Issue.record("Unexpected launcher error: \(error)")
				return
			}
		} catch {
			Issue.record("Unexpected error: \(error)")
		}
	}

	@Test
	func eligibilityHonorsVersionWindowDatesAndSeenIDs() throws {
		let now = Date(timeIntervalSince1970: 1_800_000_000)
		let announcement = LauncherAnnouncement(
			id: "feedback",
			enabled: true,
			title: "Feedback",
			body: "Tell us what you think.",
			actionTitle: nil,
			actionURL: nil,
			minimumVersion: "0.2.0",
			maximumVersion: "0.3.0",
			startsAt: now.addingTimeInterval(-60),
			endsAt: now.addingTimeInterval(60)
		)

		#expect(
			announcement.isEligible(currentVersion: "0.2.0", now: now, seenIDs: [])
		)
		#expect(
			!announcement.isEligible(currentVersion: "0.1.0", now: now, seenIDs: [])
		)
		#expect(
			!announcement.isEligible(
				currentVersion: "0.2.0", now: now, seenIDs: ["feedback"])
		)
	}
}

private func makeMockSession() -> URLSession {
	let configuration = URLSessionConfiguration.ephemeral
	configuration.protocolClasses = [MockURLProtocol.self]
	return URLSession(configuration: configuration)
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
	typealias Result = Swift.Result<(HTTPURLResponse, Data), Error>

	private static let lock = NSLock()
	nonisolated(unsafe) static var handler: ((URLRequest) -> Result)?

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		guard let handler = Self.lock.withLock({ Self.handler }) else {
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

	static func setHandler(_ handler: @escaping (URLRequest) -> Result) {
		lock.withLock { Self.handler = handler }
	}

	static func reset() {
		lock.withLock { handler = nil }
	}
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
