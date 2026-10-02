// SPDX-License-Identifier: MPL-2.0

import Foundation

struct WineProcessRetirementTimeout: Error, Sendable {}

/// Serializes Wine process creation with shutdown and retains children until they exit.
final class WineProcessSpawnGate: @unchecked Sendable {
	private let lock = NSLock()
	private let beforeSpawnAttempt: @Sendable () -> Void
	private var allowsSpawn = true
	private var processes: [ObjectIdentifier: Process] = [:]

	init(beforeSpawnAttempt: @escaping @Sendable () -> Void = {}) {
		self.beforeSpawnAttempt = beforeSpawnAttempt
	}

	func runIfAllowed<T>(process: Process, _ operation: () throws -> T) throws -> T {
		beforeSpawnAttempt()
		lock.lock()
		defer { lock.unlock() }
		guard allowsSpawn else { throw CancellationError() }
		let identifier = ObjectIdentifier(process)
		processes[identifier] = process
		do {
			return try operation()
		} catch {
			processes.removeValue(forKey: identifier)
			throw error
		}
	}

	func denyFurtherSpawns() {
		lock.lock()
		allowsSpawn = false
		let processes = Array(self.processes.values)
		lock.unlock()

		for process in processes where process.isRunning {
			process.terminate()
		}
	}

	func waitForRetirement(timeout: Duration) async throws {
		let clock = ContinuousClock()
		let deadline = clock.now.advanced(by: timeout)
		while true {
			guard try hasUnretiredProcesses() else { return }
			guard clock.now < deadline else { throw WineProcessRetirementTimeout() }
			try await Task.sleep(
				for: min(
					AppConstants.Timeouts.processRetirementPollInterval,
					clock.now.duration(to: deadline)
				)
			)
		}
	}

	private func hasUnretiredProcesses() throws -> Bool {
		lock.lock()
		guard !allowsSpawn else {
			lock.unlock()
			throw WineProcessRetirementTimeout()
		}
		let children = processes
		lock.unlock()

		for (identifier, process) in children where !process.isRunning {
			lock.lock()
			if processes[identifier] === process {
				processes.removeValue(forKey: identifier)
			}
			lock.unlock()
		}

		lock.lock()
		let hasUnretiredProcesses = !processes.isEmpty
		lock.unlock()
		return hasUnretiredProcesses
	}
}
