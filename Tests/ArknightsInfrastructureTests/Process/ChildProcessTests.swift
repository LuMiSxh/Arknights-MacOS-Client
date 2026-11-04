// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Darwin
import Foundation
import Testing

@testable import ArknightsInfrastructure

struct ChildProcessTests {
	/// A task cancelled before `run` starts must never spawn the child.
	@Test(.timeLimit(.minutes(1)))
	func cancellingBeforeStartDoesNotSpawnTheChild() async throws {
		let directory = try TemporaryDirectory("child-process-cancel")
		defer { directory.remove() }
		let marker = directory.url.appending(path: "spawned")
		let process = ChildProcess(
			executable: URL(filePath: "/bin/sh"),
			arguments: ["-c", ": > '\(marker.path)'"],
			output: .file(.nullDevice)
		)
		let gate = Signal()
		let task = Task {
			await gate.wait()
			return try await process.run()
		}
		task.cancel()
		gate.fire()

		await #expect(throws: CancellationError.self) {
			_ = try await task.value
		}
		#expect(!FileManager.default.fileExists(atPath: marker.path))
	}

	/// `.discarded` drains both streams, drops them, and still reports the exit status.
	@Test(.timeLimit(.minutes(1)))
	func discardedOutputIsDrainedAndDropped() async throws {
		let process = ChildProcess(
			executable: URL(filePath: "/bin/sh"),
			arguments: ["-c", "printf 'noise'; exit 3"],
			output: .discarded
		)

		let result = try await process.run()

		#expect(result.status == 3)
		#expect(result.output.isEmpty)
	}

	/// Cancelling a `.discarded` run terminates the child and resumes only after it exits.
	@Test(.timeLimit(.minutes(1)))
	func cancellingADiscardedRunWaitsForTheChildToExit() async throws {
		let directory = try TemporaryDirectory("child-process-discard-cancel")
		defer { directory.remove() }
		let pidFile = directory.url.appending(path: "helper.pid")
		let process = ChildProcess(
			executable: URL(filePath: "/bin/sh"),
			arguments: [
				"-c",
				"""
				trap 'exit 0' TERM
				echo $$ > '\(pidFile.path).tmp' && mv '\(pidFile.path).tmp' '\(pidFile.path)'
				while :; do :; done
				""",
			],
			output: .discarded
		)
		let task = Task { try await process.run() }
		await waitForFile(at: pidFile)

		task.cancel()
		await #expect(throws: CancellationError.self) {
			_ = try await task.value
		}

		let pid = try #require(readPID(at: pidFile))
		#expect(Darwin.kill(pid, 0) == -1)
		#expect(errno == ESRCH)
	}

	/// `start()` returns while the child runs; `wait()` then reports its result.
	@Test(.timeLimit(.minutes(1)))
	func startThenWaitReportsTheResult() async throws {
		let directory = try TemporaryDirectory("child-process-start-wait")
		defer { directory.remove() }
		let started = directory.url.appending(path: "started")
		let release = directory.url.appending(path: "release")
		defer {
			if !FileManager.default.fileExists(atPath: release.path) {
				_ = FileManager.default.createFile(atPath: release.path, contents: Data())
			}
		}
		let process = ChildProcess(
			executable: URL(filePath: "/bin/sh"),
			arguments: [
				"-c",
				"printf 'done'; : > '\(started.path)'; while [ ! -e '\(release.path)' ]; do :; done; exit 7",
			],
			output: .captured(maximumBytes: 64)
		)
		try process.start()
		await waitForFile(at: started)

		let wait = Task { try await process.wait() }
		_ = FileManager.default.createFile(atPath: release.path, contents: Data())
		let result = try await wait.value

		#expect(result.status == 7)
		#expect(String(decoding: result.output, as: UTF8.self) == "done")
	}

	/// `wait()` after the child exited still returns the recorded result.
	@Test(.timeLimit(.minutes(1)))
	func waitAfterExitReturnsTheRecordedResult() async throws {
		let process = ChildProcess(
			executable: URL(filePath: "/bin/sh"),
			arguments: ["-c", "printf 'closed'; exit 4"],
			output: .captured(maximumBytes: 64)
		)
		try process.start()
		_ = try process.waitSynchronously(timeout: .seconds(5))

		let result = try await process.wait()

		#expect(result.status == 4)
		#expect(String(decoding: result.output, as: UTF8.self) == "closed")
	}

	/// The blocking wait terminates after the first window and gives up after the second.
	@Test(.timeLimit(.minutes(1)))
	func synchronousWaitGivesUpWhenTheChildIgnoresTermination() async throws {
		let directory = try TemporaryDirectory("child-process-give-up")
		defer { directory.remove() }
		let pidFile = directory.url.appending(path: "helper.pid")
		let terminated = directory.url.appending(path: "terminated")
		let process = ChildProcess(
			executable: URL(filePath: "/bin/sh"),
			arguments: [
				"-c",
				"""
				trap 'printf terminated > "\(terminated.path)"' TERM
				echo $$ > '\(pidFile.path).tmp' && mv '\(pidFile.path).tmp' '\(pidFile.path)'
				while :; do :; done
				""",
			],
			output: .file(.nullDevice)
		)
		try process.start()
		await waitForFile(at: pidFile)
		let pid = try #require(readPID(at: pidFile))
		defer {
			if Darwin.kill(pid, 0) == 0 { _ = Darwin.kill(pid, SIGKILL) }
		}

		let clock = ContinuousClock()
		let startedWaiting = clock.now
		let exit = try process.waitSynchronously(timeout: .milliseconds(200))

		#expect(startedWaiting.duration(to: clock.now) < .seconds(1))
		#expect(exit.timedOut)
		#expect(exit.result == nil)
		#expect(FileManager.default.fileExists(atPath: terminated.path))
		#expect(Darwin.kill(pid, 0) == 0)
	}

	private func readPID(at url: URL) -> Int32? {
		guard let data = FileManager.default.contents(atPath: url.path) else { return nil }
		return Int32(
			String(decoding: data, as: UTF8.self)
				.trimmingCharacters(in: .whitespacesAndNewlines))
	}
}
