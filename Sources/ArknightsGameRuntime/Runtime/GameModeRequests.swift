// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation
import Synchronization

// One instance per `gamepolicyctl` executable, so tests can use a fake without sharing the quit state.
final class GameModeRequests: Sendable {
	private struct State {
		var inFlight: ChildProcess?
		var isClosed = false
	}

	private let state = Mutex(State())
	private let executable: URL
	private let quitWaitSeconds: Double

	init(
		executable: URL,
		quitWaitSeconds: Double = AppConstants.Game.gameModeQuitWaitSeconds
	) {
		self.executable = executable
		self.quitWaitSeconds = quitWaitSeconds
	}

	private func makeProcess(on: Bool) -> ChildProcess {
		ChildProcess(
			executable: executable,
			arguments: ["game-mode", "set", on ? "on" : "auto"],
			output: .file(.nullDevice)
		)
	}

	private func logStartFailure(_ error: any Error, on: Bool, log: LauncherLog) {
		log.error(
			"Failed to start gamepolicyctl for Game Mode \(on ? "on" : "auto"): \(error.localizedDescription)"
		)
	}

	private func logExit(status: Int32, on: Bool, log: LauncherLog) {
		guard status != 0 else { return }
		log.error(
			"gamepolicyctl exited with status \(status) while setting Game Mode \(on ? "on" : "auto")"
		)
	}

	// Returns after the process exits so a caller can order the next request behind it.
	@concurrent
	func setGameMode(on: Bool, log: LauncherLog) async {
		guard FileManager.default.isExecutableFile(atPath: executable.path) else {
			log.debug("Game Mode request skipped because gamepolicyctl is unavailable")
			return
		}
		let process = makeProcess(on: on)
		let started: Bool
		do {
			started = try state.withLock { state -> Bool in
				// Starting under the lock means quit either sees this process or stops it from starting.
				guard !state.isClosed else { return false }
				try process.start()
				state.inFlight = process
				return true
			}
		} catch {
			logStartFailure(error, on: on, log: log)
			return
		}
		guard started else { return }
		do {
			let result = try await process.wait()
			clear(process)
			logExit(status: result.status, on: on, log: log)
		} catch {
			clear(process)
			log.error(
				"Failed to wait for gamepolicyctl while setting Game Mode \(on ? "on" : "auto"): \(error.localizedDescription)"
			)
		}
	}

	// For app termination only, where nothing can run after the caller returns. Waits for an
	// in-flight request first so its `on` cannot land after this `off`, and rejects later ones.
	func setGameModeBlocking(on: Bool, log: LauncherLog) {
		let pending = state.withLock { state -> ChildProcess? in
			state.isClosed = true
			return state.inFlight
		}
		if let pending {
			_ = waitForQuit(pending, log: log)
		}
		guard FileManager.default.isExecutableFile(atPath: executable.path) else { return }
		let process = makeProcess(on: on)
		do {
			try process.start()
		} catch {
			logStartFailure(error, on: on, log: log)
			return
		}
		guard let result = waitForQuit(process, log: log) else { return }
		logExit(status: result.status, on: on, log: log)
	}

	private func clear(_ process: ChildProcess) {
		state.withLock { state in
			if state.inFlight === process { state.inFlight = nil }
		}
	}

	// Gives this request the same quit budget as the one it waits behind, then terminates it.
	// Returns nil when it never exits, because its exit status is then unavailable.
	private func waitForQuit(_ process: ChildProcess, log: LauncherLog) -> ChildProcess.Result? {
		do {
			let exit = try process.waitSynchronously(timeout: .seconds(quitWaitSeconds))
			if exit.timedOut {
				log.error("gamepolicyctl did not exit before quit; terminating it")
			}
			return exit.result
		} catch {
			log.error(
				"Failed to wait for gamepolicyctl before quit: \(error.localizedDescription)")
			return nil
		}
	}
}
