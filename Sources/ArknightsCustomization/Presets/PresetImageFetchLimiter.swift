// SPDX-License-Identifier: MPL-2.0

/// Bounds concurrent remote image downloads so a request's timeout clock starts when its
/// transfer starts, not while it waits for a free connection behind a full gallery grid.
actor PresetImageFetchLimiter {
	enum Priority {
		case background
		/// A user action, such as applying a preset. It jumps ahead of queued background work.
		case interactive
	}

	private struct Waiter {
		let id: Int
		let priority: Priority
		let continuation: CheckedContinuation<Void, any Error>
	}

	private let limit: Int
	private var active = 0
	private var nextWaiterID = 0
	private var waiters: [Waiter] = []

	init(limit: Int) {
		precondition(limit > 0, "A fetch limiter needs at least one slot")
		self.limit = limit
	}

	var activeCount: Int { active }
	var waitingCount: Int { waiters.count }

	/// Runs `operation` once a slot is free and always frees the slot afterwards.
	func run<T: Sendable>(
		priority: Priority,
		_ operation: @Sendable () async throws -> T
	) async throws -> T {
		try await acquire(priority: priority)
		do {
			let result = try await operation()
			release()
			return result
		} catch {
			release()
			throw error
		}
	}

	func acquire(priority: Priority) async throws {
		try Task.checkCancellation()
		if active < limit {
			active += 1
			return
		}
		let id = nextWaiterID
		nextWaiterID += 1
		try await withTaskCancellationHandler {
			try await self.wait(id: id, priority: priority)
		} onCancel: {
			Task { await self.cancelWaiter(id: id) }
		}
	}

	private func wait(id: Int, priority: Priority) async throws {
		try await withCheckedThrowingContinuation {
			(continuation: CheckedContinuation<Void, any Error>) in
			// The cancel handler can fire before this body runs; it finds no waiter then.
			if Task.isCancelled {
				continuation.resume(throwing: CancellationError())
			} else {
				waiters.append(Waiter(id: id, priority: priority, continuation: continuation))
			}
		}
	}

	func release() {
		// Interactive waiters go first; within a priority the queue is first in, first out.
		let index = waiters.firstIndex { $0.priority == .interactive } ?? waiters.indices.first
		if let index {
			// The slot passes straight to the waiter, so `active` stays unchanged.
			waiters.remove(at: index).continuation.resume()
		} else {
			active -= 1
		}
	}

	private func cancelWaiter(id: Int) {
		guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
		waiters.remove(at: index).continuation.resume(throwing: CancellationError())
	}
}
