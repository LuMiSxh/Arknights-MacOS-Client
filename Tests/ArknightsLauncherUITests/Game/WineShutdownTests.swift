// SPDX-License-Identifier: MPL-2.0

import ArknightsInfrastructure
import ArknightsTestSupport
import Darwin
import Dispatch
import Foundation
import Testing

@testable import ArknightsCore
@testable import ArknightsGameInstallation
@testable import ArknightsGameRuntime
@testable import ArknightsLauncherUI

@Test(.timeLimit(.minutes(1)))
func stopReturnsOnlyAfterWineserverWaitReleasesThePrefix() async throws {
	let storage = try TemporaryDirectory("wine-shutdown")
	defer { storage.remove() }
	let root = storage.url
	let trace = root.appending(path: "commands.log")
	let waitingMarker = root.appending(path: "wait-started")
	let releaseMarker = root.appending(path: "release-wait")
	let runtime = try makeWineRuntime(
		root: root,
		wineserverScript: """
			#!/bin/sh
			printf '%s\\n' "$1" >> '\(trace.path)'
			if [ "$1" = "-w" ]; then
			  : > '\(waitingMarker.path)'
			  while [ ! -e '\(releaseMarker.path)' ]; do /bin/sleep 0.01; done
			fi
			"""
	)
	let stop = Task {
		try await runtime.stop(
			prefixDirectory: root.appending(path: "prefix", directoryHint: .isDirectory),
			spawnGate: nil)
	}

	await waitForFile(at: waitingMarker)
	#expect(try String(contentsOf: trace, encoding: .utf8) == "-k\n-w\n")
	// Release the fake wineserver on every path so the stop task can finish.
	try Data().write(to: releaseMarker)
	try await stop.value
	#expect(try String(contentsOf: trace, encoding: .utf8) == "-k\n-w\n")
}

@Test(arguments: [(Int32(0), true), (Int32(1), false)])
func stopIsAuthoritativeWhenKillFindsNoServer(waitStatus: Int32, succeeds: Bool) async throws {
	let storage = try TemporaryDirectory("wine-kill-status")
	defer { storage.remove() }
	let root = storage.url
	let trace = root.appending(path: "commands.log")
	let runtime = try makeWineRuntime(
		root: root,
		wineserverScript: """
			#!/bin/sh
			printf '%s\\n' "$1" >> '\(trace.path)'
			if [ "$1" = "-k" ]; then exit 1; fi
			exit \(waitStatus)
			"""
	)

	var didFail = false
	do {
		try await runtime.stop(
			prefixDirectory: root.appending(path: "prefix", directoryHint: .isDirectory),
			timeout: .seconds(1),
			spawnGate: nil
		)
	} catch {
		didFail = true
	}
	#expect(didFail == !succeeds)
	#expect(try String(contentsOf: trace, encoding: .utf8) == "-k\n-w\n")
}

@Test(.timeLimit(.minutes(1)))
func timedOutWineHelperKeepsThePrefixOwnedUntilItRetires() async throws {
	let storage = try TemporaryDirectory("wine-helper-retirement")
	defer { storage.remove() }
	let root = storage.url
	let fifo = root.appending(path: "block")
	let started = root.appending(path: "started")
	let delayedConnection = root.appending(path: "late-server-connection")
	let fifoStatus = fifo.path.withCString { Darwin.mkfifo($0, 0o600) }
	#expect(fifoStatus == 0)
	let trace = root.appending(path: "commands.log")
	let runtime = try makeWineRuntime(
		root: root,
		wineserverScript: """
			#!/bin/sh
			printf '%s\\n' "$1" >> '\(trace.path)'
			if [ "$1" = "-k" ]; then
			  if [ -e '\(delayedConnection.path)' ]; then exit 0; else exit 1; fi
			fi
			exit 0
			"""
	)
	let prefixDirectory = root.appending(path: "prefix", directoryHint: .isDirectory)
	let spawnGate = WineProcessSpawnGate()
	let helperPID = root.appending(path: "helper.pid")
	let script = """
		trap '' TERM
		echo $$ > '\(helperPID.path).tmp' && mv '\(helperPID.path).tmp' '\(helperPID.path)'
		: > '\(started.path)'
		read ignored < '\(fifo.path)'
		: > '\(delayedConnection.path)'
		"""
	let waiter = ChildProcess(
		executable: URL(filePath: "/bin/sh"),
		arguments: ["-c", script],
		environment: [:],
		output: .file(.nullDevice),
		spawnGate: spawnGate
	)
	let clock = ContinuousClock()
	let startedWaiting = clock.now
	let wait = Task {
		do {
			_ = try await waiter.run(timeout: .milliseconds(500))
			return false
		} catch is ChildProcessTimeout {
			return true
		} catch {
			Issue.record("The Wine helper returned an unexpected error: \(error)")
			return false
		}
	}
	await waitForFile(at: started)
	// A failed assertion must not leave the helper blocked on the FIFO.
	defer { killHelperIfRunning(at: helperPID) }
	let didTimeOut = await wait.value
	#expect(didTimeOut)
	#expect(startedWaiting.duration(to: clock.now) < .seconds(1))

	var firstStopFailed = false
	do {
		try await runtime.stop(
			prefixDirectory: prefixDirectory,
			timeout: .seconds(1),
			spawnGate: spawnGate
		)
	} catch is GameRuntimeError {
		firstStopFailed = true
	}
	#expect(firstStopFailed)
	#expect(try String(contentsOf: trace, encoding: .utf8) == "-k\n")
	#expect(!FileManager.default.fileExists(atPath: delayedConnection.path))

	// A nonblocking open fails instead of hanging when the helper is no longer reading.
	let descriptor = fifo.path.withCString { Darwin.open($0, O_WRONLY | O_NONBLOCK) }
	guard descriptor >= 0 else {
		Issue.record("The Wine helper stopped reading the FIFO before the test released it.")
		return
	}
	let release = Data("connect\n".utf8)
	let written = release.withUnsafeBytes {
		Darwin.write(descriptor, $0.baseAddress, $0.count)
	}
	Darwin.close(descriptor)
	guard written == release.count else {
		Issue.record("The Wine helper did not receive the FIFO release.")
		return
	}
	await waitForFile(at: delayedConnection)
	try await runtime.stop(
		prefixDirectory: prefixDirectory,
		timeout: .seconds(1),
		spawnGate: spawnGate
	)
	#expect(try String(contentsOf: trace, encoding: .utf8) == "-k\n-k\n-k\n-w\n")
}

/// Kills the fake Wine helper when a failed assertion left it running.
private func killHelperIfRunning(at pidFile: URL) {
	guard
		let data = FileManager.default.contents(atPath: pidFile.path),
		let pid = Int32(
			String(decoding: data, as: UTF8.self)
				.trimmingCharacters(in: .whitespacesAndNewlines)),
		Darwin.kill(pid, 0) == 0
	else { return }
	_ = Darwin.kill(pid, SIGKILL)
}

@Test(arguments: [false, true])
@MainActor
func terminationDuringLaunchPreventsWineProcessesFromSpawning(
	pendingRegistryMigration: Bool
) async throws {
	let fixture = try makeLaunchFixture(pendingRegistryMigration: pendingRegistryMigration)
	defer { fixture.storage.remove() }
	let api = BlockingBrandingAPI()
	let model = makeModel(api: api, installer: ControllableInstaller())
	await api.waitForBrandingRequest()
	let reachedSpawn = Signal()
	let continueSpawn = DispatchSemaphore(value: 0)
	let spawnGate = WineProcessSpawnGate {
		reachedSpawn.fire()
		continueSpawn.wait()
	}
	let sessionID = UUID()
	model.beginTestGameSession(
		.launchingGame(sessionID: sessionID, processIdentifier: nil),
		region: .global,
		spawnGate: spawnGate
	)
	#expect(model.gameSession.sessionLease != nil)
	let launch = Task {
		try await fixture.runtime.launch(
			gameExecutable: fixture.gameExecutable,
			prefixDirectory: fixture.prefixDirectory,
			displayConfiguration: WineDisplayConfiguration(backingScaleFactor: 1),
			frameRateLimit: GameLaunchOptions.default.frameRateLimit,
			logURL: fixture.logURL,
			spawnGate: spawnGate
		)
	}

	let arrived = await reachedSpawn.wait(timeout: .seconds(2))
	#expect(arrived)
	if !arrived {
		continueSpawn.signal()
		do {
			_ = try await launch.value
			Issue.record("The launch fixture completed without reaching the spawn barrier.")
		} catch {
			Issue.record("The launch fixture failed before the spawn barrier: \(error)")
		}
		await api.resolveBranding()
		return
	}
	model.gameSession.prepareForApplicationTermination()
	launch.cancel()
	#expect(model.gameSession.applicationTerminationRequested)
	#expect(
		model.lifecycle.activity
			== .stoppingGame(sessionID: sessionID, processIdentifier: nil)
	)
	continueSpawn.signal()
	do {
		_ = try await launch.value
		Issue.record("A launch denied by termination unexpectedly spawned the game.")
	} catch is CancellationError {
	} catch {
		Issue.record("Launch failed for an unexpected reason: \(error)")
	}
	#expect(!FileManager.default.fileExists(atPath: fixture.spawnMarker.path))
	if pendingRegistryMigration {
		#expect(!FileManager.default.fileExists(atPath: fixture.helperSpawnMarker.path))
	}
	await api.resolveBranding()
}

/// Writes an executable fake `wineserver` into `root/Runtime/bin` and returns a runtime that uses it.
private func makeWineRuntime(root: URL, wineserverScript: String) throws -> WineRuntime {
	let runtimeDirectory = root.appending(path: "Runtime/bin", directoryHint: .isDirectory)
	try FileManager.default.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true)
	let wineserver = runtimeDirectory.appending(path: "wineserver")
	try Data(wineserverScript.utf8).write(to: wineserver)
	try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wineserver.path)
	return WineRuntime(
		executableURL: runtimeDirectory.appending(path: "Arknights"),
		displayName: "Fixture",
		revision: "fixture",
		compatibilityManager: GameCompatibilityManager(active: [])
	)
}

private struct LaunchFixture {
	let storage: TemporaryDirectory
	let runtime: WineRuntime
	let prefixDirectory: URL
	let gameExecutable: URL
	let logURL: URL
	let spawnMarker: URL
	let helperSpawnMarker: URL
}

private func makeLaunchFixture(pendingRegistryMigration: Bool) throws -> LaunchFixture {
	let fileManager = FileManager.default
	let storage = try TemporaryDirectory("wine-launch-test")
	let root = storage.url
	let runtimeRoot = root.appending(path: "Runtime", directoryHint: .isDirectory)
	let runtimeDirectory = runtimeRoot.appending(path: "bin", directoryHint: .isDirectory)
	let gameDirectory = root.appending(path: "Game", directoryHint: .isDirectory)
	let prefixDirectory = root.appending(path: "prefix", directoryHint: .isDirectory)
	try fileManager.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true)
	try fileManager.createDirectory(at: gameDirectory, withIntermediateDirectories: true)
	try fileManager.createDirectory(at: prefixDirectory, withIntermediateDirectories: true)
	try fileManager.createDirectory(
		at: prefixDirectory.appending(path: "dosdevices", directoryHint: .isDirectory),
		withIntermediateDirectories: true
	)
	let spawnMarker = root.appending(path: "game-spawned")
	let helperSpawnMarker = root.appending(path: "registry-helper-started")
	let executable = runtimeDirectory.appending(path: "Arknights")
	let executableScript = """
		#!/bin/sh
		case "$1" in
		  regedit.exe) : > '\(helperSpawnMarker.path)' ;;
		  *Arknights.exe) : > '\(spawnMarker.path)' ;;
		esac
		exit 0
		"""
	try Data(executableScript.utf8).write(to: executable)
	try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
	let gameExecutable = gameDirectory.appending(path: "Arknights.exe")
	try Data("fixture".utf8).write(to: gameExecutable)
	try Data("registry".utf8).write(to: prefixDirectory.appending(path: "system.reg"))
	try RuntimeMigrationStore().save(
		RuntimeMigrationState(
			runtimeRevision: "fixture",
			completed: pendingRegistryMigration
				? [.initializeWinePrefix, .installDXMT]
				: RuntimeMigration.allCases
		),
		to: prefixDirectory
	)
	let payloadDirectory = runtimeRoot.appending(path: "DXMT/x64", directoryHint: .isDirectory)
	try fileManager.createDirectory(at: payloadDirectory, withIntermediateDirectories: true)
	for library in WineRuntime.dxmtLibraryNames {
		try Data("fixture".utf8).write(to: payloadDirectory.appending(path: library))
	}
	let runtime = WineRuntime(
		executableURL: executable,
		displayName: "Fixture",
		revision: "fixture",
		compatibilityManager: GameCompatibilityManager(active: [])
	)
	return LaunchFixture(
		storage: storage,
		runtime: runtime,
		prefixDirectory: prefixDirectory,
		gameExecutable: gameExecutable,
		logURL: root.appending(path: "Logs/game.log"),
		spawnMarker: spawnMarker,
		helperSpawnMarker: helperSpawnMarker
	)
}
