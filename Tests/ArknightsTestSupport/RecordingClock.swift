// SPDX-License-Identifier: MPL-2.0

import Synchronization

/// A clock that returns from every sleep at once and records what was requested.
package final class RecordingClock: Clock, @unchecked Sendable {
	package typealias Instant = TestClockInstant

	package struct Sleep: Equatable, Sendable {
		package let duration: Duration
		package let tolerance: Duration?
	}

	private struct State {
		var elapsed = Duration.zero
		var recorded: [Sleep] = []
	}

	private let state = Mutex(State())

	package init() {}

	package var now: Instant { Instant(offset: state.withLock { $0.elapsed }) }
	package var minimumResolution: Duration { .nanoseconds(1) }
	package var sleeps: [Sleep] { state.withLock { $0.recorded } }

	package func sleep(until deadline: Instant, tolerance: Duration?) async throws {
		try Task.checkCancellation()
		state.withLock { state in
			state.recorded.append(
				Sleep(duration: state.elapsed.distance(to: deadline.offset), tolerance: tolerance))
			state.elapsed = max(state.elapsed, deadline.offset)
		}
	}
}

extension Duration {
	fileprivate func distance(to other: Duration) -> Duration { other - self }
}
