// SPDX-License-Identifier: MPL-2.0

import Foundation

/// A clock that moves only when a test advances it. Sleeping is unsupported.
package final class AdvancingClock: Clock, @unchecked Sendable {
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

	private let lock = NSLock()
	private var elapsed = Duration.zero

	package init() {}

	package var now: Instant { lock.withLock { Instant(offset: elapsed) } }
	package var minimumResolution: Duration { .zero }

	package func advance(by duration: Duration) {
		lock.withLock { elapsed += duration }
	}

	package func sleep(until deadline: Instant, tolerance: Duration?) async throws {
		throw CancellationError()
	}
}
