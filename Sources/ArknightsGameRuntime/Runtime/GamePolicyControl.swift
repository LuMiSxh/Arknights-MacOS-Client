// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Synchronization

// Game Mode can't see the actual Windows game process through Wine (it only sees the
// wrapper), so the only way to activate it is Apple's own `gamepolicyctl`, which ships solely
// inside the full Xcode.app (not the standalone Command Line Tools) — most players won't have it.
package enum GamePolicyControl {
	static let executablePath = "/Applications/Xcode.app/Contents/Developer/usr/bin/gamepolicyctl"

	package static func isAvailable(fileManager: FileManager = .default) -> Bool {
		fileManager.isExecutableFile(atPath: executablePath)
	}

	private struct State {
		var inFlight: (process: Process, exited: DispatchSemaphore)?
		var isClosed = false
	}

	private static let state = Mutex(State())

	private static func makeProcess(on: Bool) -> Process {
		let process = Process()
		process.executableURL = URL(filePath: executablePath)
		process.arguments = ["game-mode", "set", on ? "on" : "auto"]
		process.standardOutput = FileHandle.nullDevice
		process.standardError = FileHandle.nullDevice
		return process
	}

	private static func logExit(of process: Process, on: Bool, log: LauncherLog) {
		guard process.terminationStatus != 0 else { return }
		log.error(
			"gamepolicyctl exited with status \(process.terminationStatus) while setting Game Mode \(on ? "on" : "auto")"
		)
	}

	// Spawning the process blocks, so it runs off the caller's actor. Returns after the process
	// exits so a caller can order the next request behind it. Records start or exit failures.
	@concurrent
	static func setGameMode(on: Bool, log: LauncherLog) async {
		guard isAvailable() else {
			log.debug("Game Mode request skipped because gamepolicyctl is unavailable")
			return
		}
		let process = makeProcess(on: on)
		let exited = DispatchSemaphore(value: 0)
		await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
			process.terminationHandler = { process in
				logExit(of: process, on: on, log: log)
				state.withLock { $0.inFlight = nil }
				exited.signal()
				continuation.resume()
			}
			// Starting under the lock means quit either sees this process or stops it from starting.
			state.withLock { state in
				guard !state.isClosed else {
					process.terminationHandler = nil
					continuation.resume()
					return
				}
				do {
					try process.run()
					state.inFlight = (process, exited)
				} catch {
					log.error(
						"Failed to start gamepolicyctl for Game Mode \(on ? "on" : "auto"): \(error.localizedDescription)"
					)
					continuation.resume()
				}
			}
		}
	}

	// For app termination only, where nothing can run after the caller returns. Waits for an
	// in-flight request first so its `on` cannot land after this `off`, and rejects later ones.
	static func setGameModeBlocking(on: Bool, log: LauncherLog) {
		let pending = state.withLock { state in
			state.isClosed = true
			return state.inFlight
		}
		if let (running, exited) = pending,
			exited.wait(timeout: .now() + AppConstants.Game.gameModeQuitWaitSeconds) == .timedOut
		{
			log.error("gamepolicyctl did not exit before quit; terminating it")
			running.terminate()
			_ = exited.wait(timeout: .now() + AppConstants.Game.gameModeQuitWaitSeconds)
		}
		guard isAvailable() else { return }
		let process = makeProcess(on: on)
		do {
			try process.run()
		} catch {
			log.error(
				"Failed to start gamepolicyctl for Game Mode \(on ? "on" : "auto"): \(error.localizedDescription)"
			)
			return
		}
		process.waitUntilExit()
		logExit(of: process, on: on, log: log)
	}
}
