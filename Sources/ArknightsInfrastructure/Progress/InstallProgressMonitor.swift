// SPDX-License-Identifier: MPL-2.0

// One install-wide ticker keeps stall detection and the displayed rate fresh while bytes are
// not arriving.
package enum InstallProgressMonitor {
	// The monitor is cancelled and awaited on every exit path, so no progress callback outlives
	// the call.
	package static func run<Result>(
		interval: Duration,
		clock: any Clock<Duration> = ContinuousClock(),
		emit: @escaping @Sendable () async -> Void,
		operation: () async throws -> Result
	) async rethrows -> Result {
		let monitor = Task {
			await tick(interval: interval, clock: clock, emit: emit)
		}
		let result: Result
		do {
			result = try await operation()
		} catch {
			monitor.cancel()
			await monitor.value
			throw error
		}
		monitor.cancel()
		await monitor.value
		return result
	}

	private static func tick(
		interval: Duration,
		clock: any Clock<Duration>,
		emit: @Sendable () async -> Void
	) async {
		do {
			while !Task.isCancelled {
				try await clock.sleep(for: interval, tolerance: interval / 10)
				guard !Task.isCancelled else { return }
				await emit()
			}
		} catch {
			// Only cancellation ends the sleep: the install finished, failed, or paused.
		}
	}
}
