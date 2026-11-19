// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Synchronization

/// A clock whose sleeps wait until a test calls `release()`, so a timeout fires only on demand.
///
/// `release()` ends only the sleeps registered at that moment. A test that needs every sleeper
/// released awaits `waitForSleepers(_:)` first, because a sleep that registers later stays held.
final class HeldClock: Clock, Sendable {
	struct Instant: InstantProtocol {
		var offset: Duration

		func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
		func duration(to other: Instant) -> Duration { other.offset - offset }
		static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
	}

	private struct State {
		var waiters: [UUID: CheckedContinuation<Void, any Error>] = [:]
		var countWatchers: [(count: Int, signal: Signal)] = []
	}

	private let state = Mutex(State())

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
				let waiter = state.withLock { $0.waiters.removeValue(forKey: id) }
				waiter?.resume(throwing: CancellationError())
			}
		)
	}

	private func register(_ continuation: CheckedContinuation<Void, any Error>, id: UUID) {
		let (isCancelled, ready) = state.withLock { value -> (Bool, [Signal]) in
			guard !Task.isCancelled else { return (true, []) }
			value.waiters[id] = continuation
			let count = value.waiters.count
			let ready = value.countWatchers.filter { $0.count <= count }.map(\.signal)
			value.countWatchers.removeAll { $0.count <= count }
			return (false, ready)
		}
		if isCancelled { continuation.resume(throwing: CancellationError()) }
		for signal in ready { signal.fire() }
	}

	/// Returns once `count` sleeps are waiting, or `false` after `timeout` so a test fails instead
	/// of hanging.
	func waitForSleepers(_ count: Int, timeout: Duration = .seconds(10)) async -> Bool {
		let signal = Signal()
		let alreadyReady = state.withLock { value -> Bool in
			if value.waiters.count >= count { return true }
			value.countWatchers.append((count, signal))
			return false
		}
		return alreadyReady ? true : await signal.wait(timeout: timeout)
	}

	/// Ends every sleep that is waiting.
	func release() {
		let pending = state.withLock { value in
			defer { value.waiters.removeAll() }
			return Array(value.waiters.values)
		}
		for waiter in pending { waiter.resume() }
	}
}
