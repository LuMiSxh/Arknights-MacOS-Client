// SPDX-License-Identifier: MPL-2.0

/// Owns at most one in-flight task and rejects results from replaced or invalidated work.
///
/// Starting new work cancels the previous task. After every suspension, the work calls
/// ``owns(_:)`` with its token before it publishes anything: cancellation alone is not ownership.
@MainActor
package final class TaskSlot {
	package struct Token: Equatable, Sendable {
		fileprivate let value: UInt64
	}

	private var task: Task<Void, Never>?
	private var current = Token(value: 0)
	private var isActive = false

	package init() {}

	/// Cancels the running task and starts `operation` under a fresh token.
	@discardableResult
	package func replace(
		priority: TaskPriority? = nil,
		_ operation: @escaping @MainActor (Token) async -> Void
	) -> Task<Void, Never> {
		let token = begin()
		let task = Task(priority: priority) { await operation(token) }
		self.task = task
		return task
	}

	/// Cancels the running task and returns a fresh token for work the caller runs itself.
	package func begin() -> Token {
		task?.cancel()
		task = nil
		current = Token(value: current.value + 1)
		isActive = true
		return current
	}

	package func owns(_ token: Token) -> Bool {
		isActive && current == token
	}

	/// Cancels the running task and makes every outstanding token stale.
	package func invalidate() {
		task?.cancel()
		task = nil
		isActive = false
		current = Token(value: current.value + 1)
	}
}
