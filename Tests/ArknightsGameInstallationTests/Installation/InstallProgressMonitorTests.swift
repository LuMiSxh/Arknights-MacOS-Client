// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation

/// A clock whose sleeps complete only when the test fires a tick.
private final class ManualTickClock: Clock, @unchecked Sendable {
	struct Instant: InstantProtocol {
		var offset: Duration = .zero
		func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
		func duration(to other: Instant) -> Duration { other.offset - offset }
		static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
	}

	private struct Sleeper {
		let id: UInt64
		let continuation: CheckedContinuation<Void, Error>
	}

	private let lock = NSLock()
	private var sleepers: [Sleeper] = []
	private var nextID: UInt64 = 0

	var now: Instant { Instant() }
	var minimumResolution: Duration { .zero }

	private var waiting: Int { lock.withLock { sleepers.count } }

	func sleep(until deadline: Instant, tolerance: Duration?) async throws {
		let id = lock.withLock {
			nextID += 1
			return nextID
		}
		try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				// Registering and checking cancellation under one lock closes the window where
				// `onCancel` runs before the sleeper exists and the sleep would never end.
				let wasCancelled = lock.withLock { () -> Bool in
					if Task.isCancelled { return true }
					sleepers.append(Sleeper(id: id, continuation: continuation))
					return false
				}
				if wasCancelled { continuation.resume(throwing: CancellationError()) }
			}
		} onCancel: {
			let sleeper = lock.withLock { () -> Sleeper? in
				guard let index = sleepers.firstIndex(where: { $0.id == id }) else { return nil }
				return sleepers.remove(at: index)
			}
			sleeper?.continuation.resume(throwing: CancellationError())
		}
	}

	/// Waits until a monitor sleeps, then wakes it.
	func tick() async {
		while waiting == 0 { await Task.yield() }
		let sleeper = lock.withLock { sleepers.removeFirst() }
		sleeper.continuation.resume()
	}
}

private actor UpdateLog {
	private(set) var updates: [DownloadProgress] = []
	func record(_ update: DownloadProgress) { updates.append(update) }

	nonisolated var handler: GameInstaller.ProgressHandler {
		{ [self] update in await record(update) }
	}

	func waitForCount(_ count: Int) async {
		while updates.count < count { await Task.yield() }
	}
}

struct InstallProgressMonitorTests {
	@Test
	func tickReportsAStallWhenNoBytesArrive() async {
		let downloadClock = AdvancingClock()
		let counter = ProgressCounter(totalBytes: 100, totalFiles: 2, clock: downloadClock)
		let monitorClock = ManualTickClock()
		let log = UpdateLog()
		await InstallProgressMonitor.run(
			counter: counter, fallbackFile: "a", clock: monitorClock,
			progress: log.handler
		) {
			_ = await counter.add(bytes: 10, file: "a")
			_ = await counter.add(bytes: 10, file: "b")
			downloadClock.advance(by: AppConstants.Network.transferRateStallTimeout + .seconds(1))
			await monitorClock.tick()
			await log.waitForCount(1)
		}
		let update = await log.updates[0]
		#expect(update.isTransferStalled)
		#expect(update.currentFile == "b")
	}
}
