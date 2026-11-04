// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

struct GameModeRequestsTests {
	private func makeFakeGamePolicyControl(in directory: URL, script: String) throws -> URL {
		let executable = directory.appending(path: "gamepolicyctl")
		try script.write(to: executable, atomically: true, encoding: .utf8)
		try FileManager.default.setAttributes(
			[.posixPermissions: 0o755], ofItemAtPath: executable.path)
		return executable
	}

	/// A hung `gamepolicyctl` must not hold up quit: the blocking request terminates it and returns.
	/// A hung `gamepolicyctl` must not hold up quit: the blocking request terminates it and returns.
	@Test(.timeLimit(.minutes(1)))
	func quitTerminatesAHungGamePolicyControl() throws {
		let directory = try TemporaryDirectory("game-mode-quit")
		defer { directory.remove() }
		let started = directory.url.appending(path: "started")
		let terminated = directory.url.appending(path: "terminated")
		let fake = try makeFakeGamePolicyControl(
			in: directory.url,
			script: """
				#!/bin/sh
				trap ': > "\(terminated.path)"; exit 0' TERM
				: > "\(started.path)"
				while :; do :; done
				""")
		let log = LauncherLog(fileURL: directory.url.appending(path: "launcher.log"))
		let requests = GameModeRequests(executable: fake, quitWaitSeconds: 0.3)

		requests.setGameModeBlocking(on: false, log: log)

		#expect(FileManager.default.fileExists(atPath: started.path))
		#expect(FileManager.default.fileExists(atPath: terminated.path))
	}

	/// Quit waits for an in-flight `on` before it requests `auto`, so the `on` cannot land last.
	@Test(.timeLimit(.minutes(1)))
	func quitWaitsForAnInFlightRequestBeforeTurningGameModeOff() async throws {
		let directory = try TemporaryDirectory("game-mode-order")
		defer { directory.remove() }
		let root = directory.url
		let trace = root.appending(path: "requests.log")
		let started = root.appending(path: "started")
		let pidFile = root.appending(path: "helper.pid")
		let fake = try makeFakeGamePolicyControl(
			in: root,
			script: """
				#!/bin/sh
				if [ "$3" = "on" ]; then
				  trap 'printf "on-terminated\\n" >> "\(trace.path)"; exit 0' TERM
				  printf 'on-start\\n' >> "\(trace.path)"
				  echo $$ > "\(pidFile.path).tmp" && mv "\(pidFile.path).tmp" "\(pidFile.path)"
				  : > "\(started.path)"
				  while :; do :; done
				fi
				printf '%s\\n' "$3" >> "\(trace.path)"
				""")
		let log = LauncherLog(fileURL: root.appending(path: "launcher.log"))
		let requests = GameModeRequests(executable: fake, quitWaitSeconds: 0.2)
		let onRequest = Task { await requests.setGameMode(on: true, log: log) }
		await waitForFile(at: started)
		defer {
			onRequest.cancel()
			killHelper(at: pidFile)
		}

		requests.setGameModeBlocking(on: false, log: log)

		let observed: String
		do {
			observed = try String(contentsOf: trace, encoding: .utf8)
		} catch {
			Issue.record("Could not read the Game Mode request order: \(error)")
			return
		}
		#expect(observed == "on-start\non-terminated\nauto\n")
		onRequest.cancel()
		await onRequest.value
	}

	/// Quitting closes the gate, so a later request cannot start another `gamepolicyctl`.
	@Test(.timeLimit(.minutes(1)))
	func quitRejectsLaterRequestsWithoutStartingAProcess() async throws {
		let directory = try TemporaryDirectory("game-mode-closed")
		defer { directory.remove() }
		let trace = directory.url.appending(path: "requests.log")
		let fake = try makeFakeGamePolicyControl(
			in: directory.url,
			script: """
				#!/bin/sh
				printf '%s\\n' "$3" >> "\(trace.path)"
				exit 0
				""")
		let log = LauncherLog(fileURL: directory.url.appending(path: "launcher.log"))
		let requests = GameModeRequests(executable: fake, quitWaitSeconds: 1)

		requests.setGameModeBlocking(on: false, log: log)
		#expect(try String(contentsOf: trace, encoding: .utf8) == "auto\n")

		await requests.setGameMode(on: false, log: log)

		#expect(try String(contentsOf: trace, encoding: .utf8) == "auto\n")
	}

	private func killHelper(at pidFile: URL) {
		guard
			let data = FileManager.default.contents(atPath: pidFile.path),
			let pid = Int32(
				String(decoding: data, as: UTF8.self)
					.trimmingCharacters(in: .whitespacesAndNewlines)),
			Darwin.kill(pid, 0) == 0
		else { return }
		_ = Darwin.kill(pid, SIGKILL)
	}
}
