// SPDX-License-Identifier: MPL-2.0

import Foundation
import Synchronization
import Testing

/// Suspends until `condition` holds. It re-checks only when an `@Observable` value the condition read changes.
///
/// The condition must read `@Observable` state. Other state never notifies, so the wait would never end;
/// await a `Signal` from the fake instead.
///
/// After `timeout` the wait gives up and records an issue, so a broken contract fails instead of hanging.
@MainActor
package func waitForCondition(
	timeout: Duration = .seconds(10),
	sourceLocation: SourceLocation = #_sourceLocation,
	_ condition: @escaping () -> Bool
) async {
	let wake = ConditionWake()
	let timer = Task {
		guard (try? await Task.sleep(for: timeout)) != nil else { return }
		wake.expire()
	}
	defer { timer.cancel() }
	while !condition() {
		guard !wake.expired else {
			Issue.record("Condition not met within \(timeout)", sourceLocation: sourceLocation)
			return
		}
		await withCheckedContinuation { continuation in
			wake.arm(continuation)
			withObservationTracking {
				_ = condition()
			} onChange: {
				wake.wakeWaiter()
			}
		}
	}
}

/// Holds the continuation of the wait in flight. The timer and the observation both resume it,
/// and whichever runs first takes it, so it resumes exactly once.
private final class ConditionWake: Sendable {
	private struct State {
		var continuation: CheckedContinuation<Void, Never>?
		var expired = false
	}

	private let state = Mutex(State())

	var expired: Bool { state.withLock { $0.expired } }

	func arm(_ continuation: CheckedContinuation<Void, Never>) {
		let resumeNow = state.withLock { value -> Bool in
			if value.expired { return true }
			value.continuation = continuation
			return false
		}
		if resumeNow { continuation.resume() }
	}

	func wakeWaiter() {
		let continuation = state.withLock { value -> CheckedContinuation<Void, Never>? in
			defer { value.continuation = nil }
			return value.continuation
		}
		continuation?.resume()
	}

	func expire() {
		state.withLock { $0.expired = true }
		wakeWaiter()
	}
}
