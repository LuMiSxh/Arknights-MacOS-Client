// SPDX-License-Identifier: MPL-2.0

/// A clock whose sleeps end only when their task is cancelled, so a deadline never fires.
package struct ParkedClock: Clock {
	package typealias Instant = TestClockInstant

	package init() {}

	package var now: Instant { Instant(offset: .zero) }
	package var minimumResolution: Duration { .nanoseconds(1) }

	package func sleep(until deadline: Instant, tolerance: Duration?) async throws {
		let (stream, continuation) = AsyncStream<Never>.makeStream()
		for await _ in stream {}
		continuation.finish()
		try Task.checkCancellation()
	}
}
