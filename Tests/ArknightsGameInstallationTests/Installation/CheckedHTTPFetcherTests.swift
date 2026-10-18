// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsInfrastructure

struct CheckedHTTPFetcherTests {
	private let first = URLRequest(url: URL(string: "https://first.example.test/a")!)
	private let second = URLRequest(url: URL(string: "https://second.example.test/a")!)

	private func fetcher(
		_ route: StubURLProtocol.Route,
		clock: RecordingClock = RecordingClock()
	) -> CheckedHTTPFetcher {
		CheckedHTTPFetcher(
			loader: BoundedHTTPDataLoader(session: route.session, maximumBufferedBytes: 1_024),
			clock: clock
		)
	}

	@Test
	func fallsBackToTheNextCandidateAndBacksOffBetweenAttempts() async throws {
		let route = StubURLProtocol.Route()
		route.handler = { request in
			let failing = request.url?.host == "first.example.test"
			return (
				makeHTTPResponse(url: request.url!, status: failing ? 503 : 200),
				Data("ok".utf8)
			)
		}
		let clock = RecordingClock()

		let result = try await fetcher(route, clock: clock).fetch(
			[first, second],
			policy: HTTPFetchPolicy(
				maximumBytes: 1_024, attemptsPerCandidate: 2, backoffStep: .milliseconds(400))
		)

		#expect(result.request.url?.host == "second.example.test")
		#expect(route.requestCount == 3)
		let sleeps = clock.sleeps
		#expect(sleeps.count == 1)
		#expect(sleeps.first?.duration == .milliseconds(400))
		#expect((sleeps.first?.tolerance ?? .zero) >= .milliseconds(40))
	}

	/// A final server error surfaces as `HTTPFetchError`; cancelling the fetch surfaces as `CancellationError`.
	@Test
	func rethrowsTheLastFailureAndMapsCancellationToCancellationError() async throws {
		let route = StubURLProtocol.Route()
		route.handler = { request in
			(makeHTTPResponse(url: request.url!, status: 500), Data("ok".utf8))
		}
		let fetcher = fetcher(route)
		let policy = HTTPFetchPolicy(maximumBytes: 1_024)

		await #expect(throws: HTTPFetchError.self) {
			try await fetcher.fetch([first], policy: policy)
		}

		let task = Task { try await fetcher.fetch([first], policy: policy) }
		task.cancel()
		await #expect(throws: CancellationError.self) { try await task.value }
	}
}
