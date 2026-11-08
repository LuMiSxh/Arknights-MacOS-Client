// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

/// A clock whose sleeps end only when their task is cancelled, so a deadline never fires.
private struct ParkedClock: Clock {
	struct Instant: InstantProtocol {
		var offset: Duration
		func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
		func duration(to other: Instant) -> Duration { other.offset - offset }
		static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
	}

	var now: Instant { Instant(offset: .zero) }
	var minimumResolution: Duration { .nanoseconds(1) }

	func sleep(until deadline: Instant, tolerance: Duration?) async throws {
		try await waitForCancellation()
	}
}

/// Suspends until the task is cancelled; the stream never yields or finishes on its own.
private func waitForCancellation() async throws {
	let stream = AsyncStream<Void>(bufferingPolicy: .bufferingNewest(1)) { _ in }
	for await _ in stream {}
	throw CancellationError()
}

/// A child that ignores SIGTERM and exits when its stdin closes.
private struct StubbornChild {
	let process = Process()
	let stdin = Pipe()
	let marker: URL

	init(directory: URL) {
		marker = directory.appending(path: "started")
		process.executableURL = URL(filePath: "/bin/sh")
		process.arguments = ["-c", "trap '' TERM; : > '\(marker.path)'; read ignored"]
		process.standardInput = stdin
	}

	func spawn(through gate: WineProcessSpawnGate) async throws {
		try gate.runIfAllowed(process: process) { try process.run() }
		await waitForFile(at: marker)
	}

	func release() throws { try stdin.fileHandleForWriting.close() }
}

@Test(.timeLimit(.minutes(1)))
func retirementWaitEndsWhenTheLastChildExits() async throws {
	let storage = try TemporaryDirectory("spawn-gate-retirement")
	defer { storage.remove() }
	let gate = WineProcessSpawnGate()
	let child = StubbornChild(directory: storage.url)
	try await child.spawn(through: gate)
	gate.denyFurtherSpawns()

	let wait = Task {
		try await gate.waitForRetirement(timeout: .seconds(30), clock: ParkedClock())
	}
	try child.release()
	try await wait.value
}

@Test(.timeLimit(.minutes(1)))
func retirementWaitReturnsAtOnceWithoutChildren() async throws {
	let gate = WineProcessSpawnGate()
	gate.denyFurtherSpawns()
	try await gate.waitForRetirement(timeout: .seconds(30), clock: ParkedClock())
}

@Test(.timeLimit(.minutes(1)))
func cancellingARetirementWaitResumesItWithoutRetiringTheChild() async throws {
	let storage = try TemporaryDirectory("spawn-gate-cancel")
	defer { storage.remove() }
	let gate = WineProcessSpawnGate()
	let child = StubbornChild(directory: storage.url)
	try await child.spawn(through: gate)
	gate.denyFurtherSpawns()

	let wait = Task {
		try await gate.waitForRetirement(timeout: .seconds(30), clock: ParkedClock())
	}
	wait.cancel()
	await #expect(throws: CancellationError.self) { try await wait.value }
	#expect(child.process.isRunning)

	try child.release()
	try await gate.waitForRetirement(timeout: .seconds(30), clock: ParkedClock())
}

@Test(.timeLimit(.minutes(1)))
func retirementWaitTimesOutWhileAChildStillRuns() async throws {
	let storage = try TemporaryDirectory("spawn-gate-timeout")
	defer { storage.remove() }
	let gate = WineProcessSpawnGate()
	let child = StubbornChild(directory: storage.url)
	try await child.spawn(through: gate)
	gate.denyFurtherSpawns()

	await #expect(throws: WineProcessRetirementTimeout.self) {
		try await gate.waitForRetirement(timeout: .seconds(30), clock: RecordingClock())
	}
	try child.release()
}

@Test
func waitingBeforeSealingIsALogicErrorNotATimeout() async {
	let gate = WineProcessSpawnGate()
	await #expect(throws: WineProcessSpawnGateNotSealed.self) {
		try await gate.waitForRetirement(timeout: .seconds(30), clock: ParkedClock())
	}
}
