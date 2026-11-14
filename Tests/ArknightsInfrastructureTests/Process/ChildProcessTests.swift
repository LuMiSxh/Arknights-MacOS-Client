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

	private func readPID(at url: URL) -> Int32? {
		guard let data = FileManager.default.contents(atPath: url.path) else { return nil }
		return Int32(
			String(decoding: data, as: UTF8.self)
				.trimmingCharacters(in: .whitespacesAndNewlines))
	}
}
