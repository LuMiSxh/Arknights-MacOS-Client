// SPDX-License-Identifier: MPL-2.0

import Foundation
import Synchronization

struct WineProcessRetirementTimeout: Error, Sendable {}

/// Thrown when callers wait for retirement before `denyFurtherSpawns()`, which is a logic error.
struct WineProcessSpawnGateNotSealed: Error, Sendable {}

// Serializes Wine process creation with shutdown and retains children until they exit.
// States: open (spawns allowed) -> sealed (no spawns; waiters resume once the last child retires).
// Each child retires through its own `terminationHandler`; nothing polls.
final class WineProcessSpawnGate: @unchecked Sendable {
	private struct State {
		var allowsSpawn = true
		var processes: [ObjectIdentifier: Process] = [:]
		var waiters: [UUID: CheckedContinuation<Void, any Error>] = [:]
	}

	private let state = Mutex(State())
	private let beforeSpawnAttempt: @Sendable () -> Void

	init(beforeSpawnAttempt: @escaping @Sendable () -> Void = {}) {
		self.beforeSpawnAttempt = beforeSpawnAttempt
	}

	func runIfAllowed<T>(process: Process, _ operation: () throws -> T) throws -> T {
		beforeSpawnAttempt()
		// The lock is held across `operation` so a spawn cannot interleave with sealing.
		return try state.withLock { state in
			guard state.allowsSpawn else { throw CancellationError() }
			let identifier = ObjectIdentifier(process)
			let previousHandler = process.terminationHandler
			process.terminationHandler = { [weak self] process in
				previousHandler?(process)
				self?.retire(process)
			}
			state.processes[identifier] = process
			do {
				return try operation()
			} catch {
				state.processes.removeValue(forKey: identifier)
				process.terminationHandler = previousHandler
				throw error
			}
		}
	}

	func denyFurtherSpawns() {
		let (processes, waiters) = state.withLock { state in
			state.allowsSpawn = false
			let waiters = state.processes.isEmpty ? Self.takeWaiters(&state) : []
			return (Array(state.processes.values), waiters)
		}
		for waiter in waiters { waiter.resume() }
		for process in processes where process.isRunning {
			process.terminate()
		}
	}

	/// Suspends until every spawned child has exited. Call after `denyFurtherSpawns()`.
	func waitForRetirement<C: Clock>(
		timeout: Duration,
		clock: C = ContinuousClock()
	) async throws where C.Duration == Duration {
		guard state.withLock({ !$0.allowsSpawn }) else { throw WineProcessSpawnGateNotSealed() }
		try await withThrowingTaskGroup(of: Void.self) { group in
			group.addTask { try await self.suspendUntilRetired() }
			group.addTask {
				try await clock.sleep(for: timeout)
				throw WineProcessRetirementTimeout()
			}
			defer { group.cancelAll() }
			try await group.next()
		}
	}

	private func suspendUntilRetired() async throws {
		let id = UUID()
		try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				let immediate = state.withLock { state -> Result<Void, any Error>? in
					// A cancellation that ran before registration would otherwise leave this parked.
					if Task.isCancelled { return .failure(CancellationError()) }
					if state.processes.isEmpty { return .success(()) }
					state.waiters[id] = continuation
					return nil
				}
				if let immediate { continuation.resume(with: immediate) }
			}
		} onCancel: {
			let waiter = state.withLock { $0.waiters.removeValue(forKey: id) }
			waiter?.resume(throwing: CancellationError())
		}
	}

	private func retire(_ process: Process) {
		let waiters = state.withLock { state -> [CheckedContinuation<Void, any Error>] in
			let identifier = ObjectIdentifier(process)
			guard state.processes[identifier] === process else { return [] }
			state.processes.removeValue(forKey: identifier)
			return state.processes.isEmpty && !state.allowsSpawn ? Self.takeWaiters(&state) : []
		}
		for waiter in waiters { waiter.resume() }
	}

	private static func takeWaiters(_ state: inout State) -> [CheckedContinuation<Void, any Error>]
	{
		defer { state.waiters.removeAll() }
		return Array(state.waiters.values)
	}
}
