// SPDX-License-Identifier: MPL-2.0

import Foundation

/// A clock whose sleeps wait until a test calls `release()`, so a timeout fires only on demand.
final class HeldClock: Clock, @unchecked Sendable {
	struct Instant: InstantProtocol {
		var offset: Duration

		func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
		func duration(to other: Instant) -> Duration { other.offset - offset }
		static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
	}

	private let lock = NSLock()
	private var waiters: [UUID: CheckedContinuation<Void, any Error>] = [:]

	var now: Instant { Instant(offset: .zero) }
	var minimumResolution: Duration { .nanoseconds(1) }

	func sleep(until deadline: Instant, tolerance: Duration?) async throws {
		let id = UUID()
		try await withTaskCancellationHandler(
			operation: {
				try await withCheckedThrowingContinuation {
					(continuation: CheckedContinuation<Void, any Error>) in
					register(continuation, id: id)
				}
			},
			onCancel: {
				let waiter = lock.withLock { waiters.removeValue(forKey: id) }
				waiter?.resume(throwing: CancellationError())
			}
		)
	}

	private func register(_ continuation: CheckedContinuation<Void, any Error>, id: UUID) {
		let isCancelled = lock.withLock {
			if !Task.isCancelled { waiters[id] = continuation }
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
		for continuation in pending { continuation.resume() }
	}
}
