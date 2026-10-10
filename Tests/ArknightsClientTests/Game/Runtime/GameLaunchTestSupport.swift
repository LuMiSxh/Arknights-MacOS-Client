// SPDX-License-Identifier: MPL-2.0

import Foundation
import Synchronization

@testable import ArknightsClient

/// A session runtime whose `stop` and `waitUntilStopped` calls finish only when the test says so.
final class ControlledLaunchRuntime: WineRuntimeSessionControlling, @unchecked Sendable {
	private struct State {
		var stopCalls = 0
		var stopSawCancellation = false
		var stopContinuation: CheckedContinuation<Void, any Error>?
		var waitCalls = 0
		var waitContinuation: CheckedContinuation<Void, any Error>?
	}

	private let blocksWait: Bool
	private let state = Mutex(State())

	init(blocksWait: Bool = false) {
		self.blocksWait = blocksWait
	}

	var stopCalls: Int { state.withLock { $0.stopCalls } }
	var stopSawCancellation: Bool { state.withLock { $0.stopSawCancellation } }
	var isStopPending: Bool { state.withLock { $0.stopContinuation != nil } }
	var isWaitPending: Bool { state.withLock { $0.waitContinuation != nil } }

	func finishStop() {
		state.withLock {
			let continuation = $0.stopContinuation
			$0.stopContinuation = nil
			return continuation
		}?.resume()
	}

	func finishWait() {
		state.withLock {
			let continuation = $0.waitContinuation
			$0.waitContinuation = nil
			return continuation
		}?.resume()
	}

	func waitUntilStopped(prefixDirectory: URL) async throws {
		guard blocksWait else { return }
		try await withCheckedThrowingContinuation { continuation in
			state.withLock {
				$0.waitCalls += 1
				$0.waitContinuation = continuation
			}
		}
	}

	func stop(prefixDirectory: URL) async throws {
		try await stop(prefixDirectory: prefixDirectory, spawnGate: nil)
	}

	func stop(prefixDirectory: URL, spawnGate: WineProcessSpawnGate?) async throws {
		state.withLock {
			$0.stopCalls += 1
			$0.stopSawCancellation = Task.isCancelled
		}
		try await withCheckedThrowingContinuation { continuation in
			state.withLock { $0.stopContinuation = continuation }
		}
	}
}

/// A clock that only moves when something sleeps on it, so timeout tests never wait.
final class ManualClock: Clock, @unchecked Sendable {
	struct Instant: InstantProtocol {
		var offset: Duration

		func advanced(by duration: Duration) -> Instant {
			Instant(offset: offset + duration)
		}

		func duration(to other: Instant) -> Duration {
			other.offset - offset
		}

		static func < (lhs: Instant, rhs: Instant) -> Bool {
			lhs.offset < rhs.offset
		}
	}

	private let lock = NSLock()
	private var elapsed = Duration.zero
	private var sleeps = 0

	var now: Instant { lock.withLock { Instant(offset: elapsed) } }
	var minimumResolution: Duration { .nanoseconds(1) }
	var sleepCount: Int { lock.withLock { sleeps } }

	func sleep(until deadline: Instant, tolerance: Duration?) async throws {
		try Task.checkCancellation()
		lock.withLock {
			sleeps += 1
			elapsed = max(elapsed, deadline.offset)
		}
		await Task.yield()
	}
}
