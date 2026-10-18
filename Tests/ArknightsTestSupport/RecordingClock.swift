// SPDX-License-Identifier: MPL-2.0

import Foundation

/// A clock that returns from every sleep at once and records what was requested.
package final class RecordingClock: Clock, @unchecked Sendable {
	package struct Instant: InstantProtocol {
		package var offset: Duration

		package func advanced(by duration: Duration) -> Instant {
			Instant(offset: offset + duration)
		}

		package func duration(to other: Instant) -> Duration {
			other.offset - offset
		}

		package static func < (lhs: Instant, rhs: Instant) -> Bool {
			lhs.offset < rhs.offset
		}
	}

	package struct Sleep: Equatable, Sendable {
		package let duration: Duration
		package let tolerance: Duration?
	}

	private let lock = NSLock()
	private var elapsed = Duration.zero
	private var recorded: [Sleep] = []

	package init() {}

	package var now: Instant { lock.withLock { Instant(offset: elapsed) } }
	package var minimumResolution: Duration { .nanoseconds(1) }
	package var sleeps: [Sleep] { lock.withLock { recorded } }

	package func sleep(until deadline: Instant, tolerance: Duration?) async throws {
		try Task.checkCancellation()
		lock.withLock {
			recorded.append(
				Sleep(duration: elapsed.distance(to: deadline.offset), tolerance: tolerance))
			elapsed = max(elapsed, deadline.offset)
		}
	}
}

extension Duration {
	fileprivate func distance(to other: Duration) -> Duration { other - self }
}
