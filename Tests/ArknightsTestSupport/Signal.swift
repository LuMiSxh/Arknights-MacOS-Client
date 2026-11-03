// SPDX-License-Identifier: MPL-2.0

import Foundation
import Synchronization

/// A one-shot event that any thread can fire and any task can await.
///
/// `wait()` returns at once when `fire()` already ran, so the two calls may come in either order.
/// Waiters are resumed outside the lock. A cancelled waiter resumes without the event, and
/// `wait(timeout:)` bounds the wait so a test that never fires fails instead of hanging.
package final class Signal: Sendable {
	private struct State {
		var fired = false
		var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]
		var cancelled: Set<UUID> = []
	}

	private let state = Mutex(State())

	package init() {}

	/// Marks the event as having happened and resumes every waiter. Later calls do nothing.
	package func fire() {
		let waiters = state.withLock { value -> [CheckedContinuation<Void, Never>] in
			guard !value.fired else { return [] }
			value.fired = true
			let waiters = Array(value.waiters.values)
			value.waiters = [:]
			return waiters
		}
		for waiter in waiters { waiter.resume() }
	}

	/// Suspends until `fire()` runs, or until the task is cancelled.
	package func wait() async {
		let id = UUID()
		await withTaskCancellationHandler {
			await withCheckedContinuation { continuation in
				let resumeNow = state.withLock { value -> Bool in
					let cancelled = value.cancelled.remove(id) != nil
					if value.fired || cancelled { return true }
					value.waiters[id] = continuation
					return false
				}
				if resumeNow { continuation.resume() }
			}
		} onCancel: {
			let continuation = state.withLock { value -> CheckedContinuation<Void, Never>? in
				guard !value.fired else { return nil }
				if let continuation = value.waiters.removeValue(forKey: id) { return continuation }
				value.cancelled.insert(id)
				return nil
			}
			continuation?.resume()
		}
	}

	/// Suspends until `fire()` runs or `timeout` passes. Returns `false` when the event did not arrive in time.
	package func wait(timeout: Duration) async -> Bool {
		await withTaskGroup(of: Bool.self) { group in
			group.addTask {
				await self.wait()
				return !Task.isCancelled
			}
			group.addTask {
				try? await Task.sleep(for: timeout)
				return false
			}
			let fired = await group.next() ?? false
			group.cancelAll()
			return fired
		}
	}
}
