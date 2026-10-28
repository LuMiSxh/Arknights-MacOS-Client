// SPDX-License-Identifier: MPL-2.0

import Foundation

/// A clock whose sleeps wait until a test calls `release()` or advances past their deadline, so a
/// timeout fires only on demand.
final class HeldClock: Clock, @unchecked Sendable {
	struct Instant: InstantProtocol {
		var offset: Duration

		func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
		func duration(to other: Instant) -> Duration { other.offset - offset }
		static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
	}

	private let lock = NSLock()
	private typealias Waiter = (
		deadline: Instant, continuation: CheckedContinuation<Void, any Error>
	)
	private var waiters: [UUID: Waiter] = [:]
	private var elapsed = Duration.zero

	var now: Instant { lock.withLock { Instant(offset: elapsed) } }
	var minimumResolution: Duration { .nanoseconds(1) }

	func sleep(until deadline: Instant, tolerance: Duration?) async throws {
		let id = UUID()
		try await withTaskCancellationHandler(
			operation: {
				try await withCheckedThrowingContinuation {
					(continuation: CheckedContinuation<Void, any Error>) in
					register(continuation, id: id, deadline: deadline)
				}
			},
			onCancel: {
				let waiter = lock.withLock { waiters.removeValue(forKey: id) }
				waiter?.continuation.resume(throwing: CancellationError())
			}
		)
	}

	private func register(
		_ continuation: CheckedContinuation<Void, any Error>,
		id: UUID,
		deadline: Instant
	) {
		let isCancelled = lock.withLock {
			if !Task.isCancelled { waiters[id] = (deadline, continuation) }
			return Task.isCancelled
		}
		if isCancelled { continuation.resume(throwing: CancellationError()) }
	}

	/// Ends every sleep that is waiting.
	func release() {
		let pending = lock.withLock {
			defer { waiters.removeAll() }
			return Array(waiters.values)
		}
		for waiter in pending { waiter.continuation.resume() }
	}

	/// Moves time forward and ends only the sleeps whose deadline has passed.
	func advance(by duration: Duration) {
		let due = lock.withLock {
			elapsed += duration
			let now = Instant(offset: elapsed)
			let ids = waiters.filter { $0.value.deadline <= now }.map(\.key)
			return ids.compactMap { waiters.removeValue(forKey: $0)?.continuation }
		}
		for continuation in due { continuation.resume() }
	}
}
