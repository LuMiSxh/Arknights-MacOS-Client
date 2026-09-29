// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

protocol WineRuntimeSessionControlling: Sendable {
	func waitUntilStopped(prefixDirectory: URL) async throws
	func stop(prefixDirectory: URL) async throws
	func stop(prefixDirectory: URL, spawnGate: WineProcessSpawnGate?) async throws
}

extension WineRuntimeSessionControlling {
	func stop(prefixDirectory: URL, spawnGate: WineProcessSpawnGate?) async throws {
		try await stop(prefixDirectory: prefixDirectory)
	}
}

extension WineRuntime: WineRuntimeSessionControlling {}

extension WineRuntime {
	func waitUntilStopped(prefixDirectory: URL) async throws {
		guard let wineserverURL else {
			throw LauncherError.runtimeConfiguration(
				"wineserver is missing from the bundled runtime.")
		}
		let status = try await runAndWait(
			executable: wineserverURL,
			arguments: ["-w"],
			environment: runtimeEnvironment(prefixDirectory: prefixDirectory),
			output: .nullDevice
		)
		guard status == 0 else {
			throw LauncherError.runtimeConfiguration(
				"Wine could not monitor the game process (status \(status)).")
		}
	}

	func stop(prefixDirectory: URL) async throws {
		try await stop(
			prefixDirectory: prefixDirectory,
			timeout: AppConstants.Timeouts.runtimeShutdown,
			spawnGate: nil
		)
	}

	func stop(prefixDirectory: URL, timeout: Duration) async throws {
		try await stop(
			prefixDirectory: prefixDirectory,
			timeout: timeout,
			spawnGate: nil
		)
	}

	func stop(prefixDirectory: URL, spawnGate: WineProcessSpawnGate?) async throws {
		try await stop(
			prefixDirectory: prefixDirectory,
			timeout: AppConstants.Timeouts.runtimeShutdown,
			spawnGate: spawnGate
		)
	}

	func stop(
		prefixDirectory: URL,
		timeout: Duration,
		spawnGate: WineProcessSpawnGate?
	) async throws {
		guard let wineserverURL else {
			throw LauncherError.runtimeConfiguration(
				"wineserver is missing from the bundled runtime.")
		}
		let clock = ContinuousClock()
		let deadline = clock.now.advanced(by: timeout)
		spawnGate?.denyFurtherSpawns()
		do {
			// Wine returns status 1 when -k finds no server; -w is the completion check.
			_ = try await runAndWait(
				executable: wineserverURL,
				arguments: ["-k"],
				environment: runtimeEnvironment(prefixDirectory: prefixDirectory),
				output: .nullDevice,
				timeout: remainingShutdownTime(clock: clock, deadline: deadline)
			)
			if let spawnGate {
				try await spawnGate.waitForRetirement(
					timeout: remainingShutdownTime(clock: clock, deadline: deadline)
				)
				_ = try await runAndWait(
					executable: wineserverURL,
					arguments: ["-k"],
					environment: runtimeEnvironment(prefixDirectory: prefixDirectory),
					output: .nullDevice,
					timeout: remainingShutdownTime(clock: clock, deadline: deadline)
				)
			}
			let waitStatus = try await runAndWait(
				executable: wineserverURL,
				arguments: ["-w"],
				environment: runtimeEnvironment(prefixDirectory: prefixDirectory),
				output: .nullDevice,
				timeout: remainingShutdownTime(clock: clock, deadline: deadline)
			)
			guard waitStatus == 0 else {
				throw LauncherError.runtimeConfiguration(
					"Wine could not finish stopping Arknights (status \(waitStatus)).")
			}
		} catch is WineProcessWaitTimeout {
			throw LauncherError.runtimeConfiguration(
				"Wine could not finish stopping Arknights before the shutdown deadline.")
		} catch is WineProcessRetirementTimeout {
			throw LauncherError.runtimeConfiguration(
				"Wine launch processes did not exit before the shutdown deadline.")
		}
	}

	func stopSynchronously(prefixDirectory: URL, log: LauncherLog? = nil) {
		guard let wineserverURL else {
			log?.error("wineserver is missing while terminating the app")
			return
		}
		let process = Process()
		process.executableURL = wineserverURL
		process.arguments = ["-k"]
		process.environment = runtimeEnvironment(prefixDirectory: prefixDirectory)
		process.standardOutput = FileHandle.nullDevice
		process.standardError = FileHandle.nullDevice
		let terminated = DispatchSemaphore(value: 0)
		process.terminationHandler = { _ in terminated.signal() }
		do {
			try process.run()
		} catch {
			log?.error(
				"Failed to start wineserver while terminating the app: \(error.localizedDescription)"
			)
			return
		}
		guard
			terminated.wait(
				timeout: .now() + AppConstants.Timeouts.processTerminateGracePeriod
			) == .timedOut
		else {
			if process.terminationStatus != 0 {
				let status = process.terminationStatus
				log?.error(
					"wineserver exited with status \(status) while terminating the app"
				)
			}
			return
		}
		log?.error("wineserver timed out while terminating the app; sending terminate")
		process.terminate()
		guard
			terminated.wait(
				timeout: .now() + AppConstants.Timeouts.processKillGracePeriod
			) == .timedOut
		else { return }
		// The process may have exited and its PID been recycled in the gap between the
		// timeout above and here; confirm it still exists before sending SIGKILL.
		guard Darwin.kill(process.processIdentifier, 0) == 0 else { return }
		let result = Darwin.kill(process.processIdentifier, SIGKILL)
		Task {
			if result == 0 {
				log?.error("wineserver required SIGKILL while terminating the app")
			} else {
				log?.error("Failed to send SIGKILL to wineserver while terminating the app")
			}
		}
	}

	private var wineserverURL: URL? {
		let candidate = executableURL.deletingLastPathComponent().appending(path: "wineserver")
		return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
	}

	func runAndWait(
		executable: URL,
		arguments: [String],
		environment: [String: String],
		output: FileHandle,
		timeout: Duration? = nil,
		spawnGate: WineProcessSpawnGate? = nil
	) async throws -> Int32 {
		try await WineProcessWaiter(
			executable: executable,
			arguments: arguments,
			environment: environment,
			output: output,
			spawnGate: spawnGate
		).wait(timeout: timeout)
	}

	private func remainingShutdownTime(
		clock: ContinuousClock,
		deadline: ContinuousClock.Instant
	) -> Duration {
		max(.zero, clock.now.duration(to: deadline))
	}
}
