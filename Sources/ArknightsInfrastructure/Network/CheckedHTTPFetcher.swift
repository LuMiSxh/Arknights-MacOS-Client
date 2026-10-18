// SPDX-License-Identifier: MPL-2.0

import Foundation

package struct HTTPFetchPolicy: Sendable {
	package var maximumBytes: Int
	package var acceptedStatusCodes: Set<Int>
	/// Attempts per candidate request, at least one.
	package var attemptsPerCandidate: Int
	/// Delay before retry `n` of one candidate is `backoffStep * n`.
	package var backoffStep: Duration

	package init(
		maximumBytes: Int,
		acceptedStatusCodes: Set<Int> = [200],
		attemptsPerCandidate: Int = 1,
		backoffStep: Duration = .zero
	) {
		self.maximumBytes = maximumBytes
		self.acceptedStatusCodes = acceptedStatusCodes
		self.attemptsPerCandidate = attemptsPerCandidate
		self.backoffStep = backoffStep
	}
}

package struct HTTPFetchResult: Sendable {
	package let data: Data
	package let response: HTTPURLResponse
	/// The candidate that produced this result.
	package let request: URLRequest
}

package enum HTTPFetchError: Error, Sendable {
	case unexpectedStatus(Int, URL?)
	case noCandidates
}

package enum HTTPCancellation {
	/// Any failure that surfaces after the task was cancelled is the cancellation itself.
	package static func resolve(_ error: any Error) -> any Error {
		Task.isCancelled || error is CancellationError ? CancellationError() : error
	}
}

/// Fetches the first candidate request that answers with an accepted status.
///
/// Candidates are tried in order, each up to `attemptsPerCandidate` times. Failures that
/// repeating cannot fix (oversized response, refused redirect) skip to the next candidate.
/// The last failure is rethrown unchanged, so each caller maps errors at its own boundary;
/// cancellation always surfaces as `CancellationError`.
package struct CheckedHTTPFetcher: Sendable {
	private let loader: BoundedHTTPDataLoader
	private let clock: any Clock<Duration>

	package init(loader: BoundedHTTPDataLoader, clock: any Clock<Duration> = ContinuousClock()) {
		self.loader = loader
		self.clock = clock
	}

	package func fetch(
		_ candidates: [URLRequest],
		policy: HTTPFetchPolicy,
		redirectValidator: (@Sendable (URL) -> Bool)? = nil
	) async throws -> HTTPFetchResult {
		let attempts = max(1, policy.attemptsPerCandidate)
		var lastError: any Error = HTTPFetchError.noCandidates
		for request in candidates {
			for attempt in 1...attempts {
				do {
					try Task.checkCancellation()
					let (data, response) = try await loader.data(
						for: request,
						maximumBytes: policy.maximumBytes,
						redirectValidator: redirectValidator
					)
					guard policy.acceptedStatusCodes.contains(response.statusCode) else {
						throw HTTPFetchError.unexpectedStatus(response.statusCode, request.url)
					}
					return HTTPFetchResult(data: data, response: response, request: request)
				} catch {
					let resolved = HTTPCancellation.resolve(error)
					if resolved is CancellationError { throw resolved }
					lastError = resolved
					guard Self.isRepeatable(resolved), attempt < attempts else { break }
					let delay = policy.backoffStep * attempt
					// 20% leeway lets the system coalesce the wake-up.
					try await clock.sleep(for: delay, tolerance: delay / 5)
				}
			}
		}
		throw lastError
	}

	private static func isRepeatable(_ error: any Error) -> Bool {
		switch error as? HTTPTransportError {
		case .responseTooLarge, .redirectRejected: false
		default: true
		}
	}
}
