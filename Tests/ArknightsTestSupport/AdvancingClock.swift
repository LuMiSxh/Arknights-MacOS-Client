// SPDX-License-Identifier: MPL-2.0

import Synchronization

/// A clock that moves only when a test advances it. Sleeping is unsupported.
package final class AdvancingClock: Clock, @unchecked Sendable {
	package typealias Instant = TestClockInstant

	private let elapsed = Mutex<Duration>(.zero)

	package init() {}

	package var now: Instant { Instant(offset: elapsed.withLock { $0 }) }
	package var minimumResolution: Duration { .zero }

	package func advance(by duration: Duration) {
		elapsed.withLock { $0 += duration }
	}

	package func sleep(until deadline: Instant, tolerance: Duration?) async throws {
		throw CancellationError()
	}
}
