// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
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
	private var totalSleeps = 0
	private var maxConcurrentSleepers = 0

	var now: Instant { Instant() }
	var minimumResolution: Duration { .zero }

	var sleepCount: Int { lock.withLock { totalSleeps } }
	var peakConcurrentSleepers: Int { lock.withLock { maxConcurrentSleepers } }
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
					totalSleeps += 1
					if Task.isCancelled { return true }
					sleepers.append(Sleeper(id: id, continuation: continuation))
					maxConcurrentSleepers = max(maxConcurrentSleepers, sleepers.count)
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

private struct ControlledDownloadClock: DownloadClock {
	let box = Box()
	final class Box: @unchecked Sendable {
		let lock = NSLock()
		var instant = ContinuousClock().now
	}
	var now: ContinuousClock.Instant { box.lock.withLock { box.instant } }
	func advance(by duration: Duration) {
		box.lock.withLock { box.instant = box.instant.advanced(by: duration) }
	}
}

struct InstallProgressMonitorTests {
	@Test
	func oneMonitorTicksForAllConcurrentFiles() async throws {
		let clock = ManualTickClock()
		let counter = ProgressCounter(totalBytes: 100, totalFiles: 3)
		let log = UpdateLog()
		await InstallProgressMonitor.run(
			counter: counter, fallbackFile: "a", clock: clock,
			progress: log.handler
		) {
			_ = await counter.add(bytes: 1, file: "a")
			_ = await counter.add(bytes: 1, file: "b")
			_ = await counter.add(bytes: 1, file: "c")
			await clock.tick()
			await log.waitForCount(1)
			_ = await counter.add(bytes: 1, file: "b")
			await clock.tick()
			await log.waitForCount(2)
		}
		let files = await log.updates.map(\.currentFile)
		#expect(files == ["c", "b"])
		#expect(clock.peakConcurrentSleepers == 1)
	}

	@Test
	func fallsBackToTheFirstFileBeforeAnyBytesArrive() async {
		let clock = ManualTickClock()
		let counter = ProgressCounter(totalBytes: 100, totalFiles: 1)
		let log = UpdateLog()
		await InstallProgressMonitor.run(
			counter: counter, fallbackFile: "first", clock: clock,
			progress: log.handler
		) {
			await clock.tick()
			await log.waitForCount(1)
		}
		#expect(await log.updates.map(\.currentFile) == ["first"])
	}

	@Test
	func tickReportsAStallWhenNoBytesArrive() async {
		let downloadClock = ControlledDownloadClock()
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

	@Test
	func monitorEndsBeforeRunReturnsOnSuccessFailureAndCancellation() async {
		struct Failure: Error {}
		for outcome in ["success", "failure", "cancellation"] {
			let clock = ManualTickClock()
			let counter = ProgressCounter(totalBytes: 1, totalFiles: 1)
			let log = UpdateLog()
			let task = Task {
				try await InstallProgressMonitor.run(
					counter: counter, fallbackFile: "a", clock: clock,
					progress: log.handler
				) {
					await clock.tick()
					await log.waitForCount(1)
					switch outcome {
					case "failure": throw Failure()
					case "cancellation": try await Task.sleep(for: .seconds(60))
					default: break
					}
				}
			}
			if outcome == "cancellation" {
				await log.waitForCount(1)
				task.cancel()
			}
			_ = try? await task.value
			let sleepsAtReturn = clock.sleepCount
			await Task.yield()
			// No further sleep begins after the run returns, so the monitor is gone.
			#expect(clock.sleepCount == sleepsAtReturn, "\(outcome)")
			#expect(clock.peakConcurrentSleepers == 1, "\(outcome)")
		}
	}
}
