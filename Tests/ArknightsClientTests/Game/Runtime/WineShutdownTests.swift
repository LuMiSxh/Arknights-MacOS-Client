// SPDX-License-Identifier: MPL-2.0

import Darwin
import Dispatch
import Foundation
import Testing

@testable import ArknightsClient

@Test
func asynchronousStopWaitsForWineServerToReleaseThePrefix() async throws {
	let fileManager = FileManager.default
	let root = fileManager.temporaryDirectory.appending(
		path: "wine-shutdown-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: root) }
	let runtimeDirectory = root.appending(path: "Runtime/bin", directoryHint: .isDirectory)
	try fileManager.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true)
	let executable = runtimeDirectory.appending(path: "Arknights")
	let trace = root.appending(path: "commands.log")
	let waitingMarker = root.appending(path: "wait-started")
	let releaseMarker = root.appending(path: "release-wait")
	let script = """
		#!/bin/sh
		printf '%s\\n' "$1" >> '\(trace.path)'
		if [ "$1" = "-w" ]; then
		  : > '\(waitingMarker.path)'
		  while [ ! -e '\(releaseMarker.path)' ]; do /bin/sleep 0.01; done
		fi
		"""
	try Data(script.utf8).write(to: runtimeDirectory.appending(path: "wineserver"))
	try fileManager.setAttributes(
		[.posixPermissions: 0o755],
		ofItemAtPath: runtimeDirectory.appending(path: "wineserver").path
	)
	let runtime = WineRuntime(
		executableURL: executable,
		displayName: "Fixture",
		revision: "fixture",
		compatibilityManager: GameCompatibilityManager(active: [])
	)
	let stop = Task {
		try await runtime.stop(
			prefixDirectory: root.appending(path: "prefix", directoryHint: .isDirectory))
	}

	let reachedWait = await waitForFixtureFile(waitingMarker, timeout: .seconds(1))
	#expect(reachedWait)
	if !reachedWait {
		try? Data().write(to: releaseMarker)
		try await stop.value
		let commands = try String(contentsOf: trace, encoding: .utf8)
		#expect(commands == "-k\n-w\n")
		return
	}
	let commandsBeforeRelease = try String(contentsOf: trace, encoding: .utf8)
	#expect(commandsBeforeRelease == "-k\n-w\n")
	try Data().write(to: releaseMarker)
	try await stop.value
}

@Test
func wineserverWaitIsAuthoritativeWhenKillFindsNoServer() async throws {
	let root = FileManager.default.temporaryDirectory.appending(
		path: "wine-kill-status-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? FileManager.default.removeItem(at: root) }
	for (name, waitStatus, shouldSucceed) in [
		("already-stopped", 0, true),
		("still-running", 1, false),
	] {
		let fixture = try makeWineserverStatusFixture(
			at: root.appending(path: name, directoryHint: .isDirectory),
			killStatus: 1,
			waitStatus: Int32(waitStatus)
		)
		var didFail = false
		do {
			try await fixture.runtime.stop(
				prefixDirectory: fixture.prefixDirectory,
				timeout: .seconds(1)
			)
		} catch {
			didFail = true
		}
		#expect(didFail == !shouldSucceed)
		#expect(try String(contentsOf: fixture.trace, encoding: .utf8) == "-k\n-w\n")
	}
}

@Test
func wineserverWaitTimeoutFailsShutdownWithoutWaitingForAChildTask() async throws {
	let root = FileManager.default.temporaryDirectory.appending(
		path: "wine-shutdown-timeout-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
	defer { try? FileManager.default.removeItem(at: root) }
	let runtimeDirectory = root.appending(path: "Runtime/bin", directoryHint: .isDirectory)
	try FileManager.default.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true)
	let fifo = root.appending(path: "block")
	let fifoStatus = fifo.path.withCString { Darwin.mkfifo($0, 0o600) }
	#expect(fifoStatus == 0)
	let trace = root.appending(path: "commands.log")
	let script = """
		#!/bin/sh
		printf '%s\\n' "$1" >> '\(trace.path)'
		if [ "$1" = "-w" ]; then read ignored < '\(fifo.path)'; fi
		"""
	let wineserver = runtimeDirectory.appending(path: "wineserver")
	try Data(script.utf8).write(to: wineserver)
	try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wineserver.path)
	let runtime = WineRuntime(
		executableURL: runtimeDirectory.appending(path: "Arknights"),
		displayName: "Fixture",
		revision: "fixture",
		compatibilityManager: GameCompatibilityManager(active: [])
	)
	let clock = ContinuousClock()
	let started = clock.now
	var didTimeOut = false
	do {
		try await runtime.stop(
			prefixDirectory: root.appending(path: "prefix", directoryHint: .isDirectory),
			timeout: .milliseconds(500)
		)
	} catch is LauncherError {
		didTimeOut = true
	} catch {
		Issue.record("Wine shutdown failed with an unexpected error: \(error)")
	}
	#expect(didTimeOut)
	#expect(started.duration(to: clock.now) < .seconds(2))
	#expect(try String(contentsOf: trace, encoding: .utf8) == "-k\n-w\n")
}

@Test
func timedOutWineHelperKeepsThePrefixOwnedUntilItRetires() async throws {
	let root = FileManager.default.temporaryDirectory.appending(
		path: "wine-helper-retirement-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
	defer { try? FileManager.default.removeItem(at: root) }
	let runtimeDirectory = root.appending(path: "Runtime/bin", directoryHint: .isDirectory)
	try FileManager.default.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true)
	let fifo = root.appending(path: "block")
	let started = root.appending(path: "started")
	let delayedConnection = root.appending(path: "late-server-connection")
	let fifoStatus = fifo.path.withCString { Darwin.mkfifo($0, 0o600) }
	#expect(fifoStatus == 0)
	let trace = root.appending(path: "commands.log")
	let wineserverScript = """
		#!/bin/sh
		printf '%s\\n' "$1" >> '\(trace.path)'
		if [ "$1" = "-k" ]; then
		  if [ -e '\(delayedConnection.path)' ]; then exit 0; else exit 1; fi
		fi
		exit 0
		"""
	let wineserver = runtimeDirectory.appending(path: "wineserver")
	try Data(wineserverScript.utf8).write(to: wineserver)
	try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wineserver.path)
	let runtime = WineRuntime(
		executableURL: runtimeDirectory.appending(path: "Arknights"),
		displayName: "Fixture",
		revision: "fixture",
		compatibilityManager: GameCompatibilityManager(active: [])
	)
	let prefixDirectory = root.appending(path: "prefix", directoryHint: .isDirectory)
	let spawnGate = WineProcessSpawnGate()
	let script = """
		trap '' TERM
		: > '\(started.path)'
		read ignored < '\(fifo.path)'
		: > '\(delayedConnection.path)'
		"""
	let waiter = WineProcessWaiter(
		executable: URL(filePath: "/bin/sh"),
		arguments: ["-c", script],
		environment: [:],
		output: .nullDevice,
		spawnGate: spawnGate
	)
	let clock = ContinuousClock()
	let startedWaiting = clock.now
	let wait = Task {
		do {
			_ = try await waiter.wait(timeout: .milliseconds(500))
			return false
		} catch is WineProcessWaitTimeout {
			return true
		} catch {
			Issue.record("The Wine helper returned an unexpected error: \(error)")
			return false
		}
	}
	let helperStarted = await waitForFixtureFile(started, timeout: .seconds(1))
	#expect(helperStarted)
	guard helperStarted else {
		_ = await wait.value
		return
	}
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
	} catch is LauncherError {
		firstStopFailed = true
	}
	#expect(firstStopFailed)
	#expect(try String(contentsOf: trace, encoding: .utf8) == "-k\n")
	#expect(!FileManager.default.fileExists(atPath: delayedConnection.path))

	let writer = try FileHandle(forWritingTo: fifo)
	try writer.write(contentsOf: Data("connect\n".utf8))
	try writer.close()
	#expect(await waitForFixtureFile(delayedConnection, timeout: .seconds(1)))
	try await runtime.stop(
		prefixDirectory: prefixDirectory,
		timeout: .seconds(1),
		spawnGate: spawnGate
	)
	#expect(try String(contentsOf: trace, encoding: .utf8) == "-k\n-k\n-k\n-w\n")
}

@Test(arguments: [false, true])
@MainActor
func terminationDuringLaunchPreventsWineProcessesFromSpawning(
	pendingRegistryMigration: Bool
) async throws {
	let fixture = try makeLaunchFixture(pendingRegistryMigration: pendingRegistryMigration)
	defer { try? FileManager.default.removeItem(at: fixture.root) }
	let api = BlockingBrandingAPI()
	let model = makeModel(api: api, installer: ControllableInstaller())
	await api.waitForBrandingRequest()
	let reachedSpawn = DispatchSemaphore(value: 0)
	let continueSpawn = DispatchSemaphore(value: 0)
	let spawnGate = WineProcessSpawnGate {
		reachedSpawn.signal()
		continueSpawn.wait()
	}
	let sessionID = UUID()
	model.gameSession.sessionLease = model.lifecycle.begin(
		.launchingGame(sessionID: sessionID, processIdentifier: nil)
	)
	#expect(model.gameSession.sessionLease != nil)
	model.gameSession.activeGameRegion = .global
	model.gameSession.activeWineProcessSpawnGate = spawnGate
	let launch = Task.detached {
		try await fixture.runtime.launch(
			gameExecutable: fixture.gameExecutable,
			prefixDirectory: fixture.prefixDirectory,
			displayConfiguration: WineDisplayConfiguration(backingScaleFactor: 1),
			logURL: fixture.logURL,
			spawnGate: spawnGate
		)
	}

	let arrived = await Task.detached {
		waitForSemaphore(reachedSpawn, timeout: .now() + 2)
	}.value
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

private func waitForSemaphore(_ semaphore: DispatchSemaphore, timeout: DispatchTime) -> Bool {
	semaphore.wait(timeout: timeout) == .success
}

private func waitForFixtureFile(_ url: URL, timeout: Duration) async -> Bool {
	let clock = ContinuousClock()
	let deadline = clock.now.advanced(by: timeout)
	while clock.now < deadline {
		if FileManager.default.fileExists(atPath: url.path) { return true }
		try? await Task.sleep(for: .milliseconds(10))
	}
	return FileManager.default.fileExists(atPath: url.path)
}

private struct WineserverStatusFixture {
	let runtime: WineRuntime
	let prefixDirectory: URL
	let trace: URL
}

private func makeWineserverStatusFixture(
	at root: URL,
	killStatus: Int32,
	waitStatus: Int32
) throws -> WineserverStatusFixture {
	let fileManager = FileManager.default
	let runtimeDirectory = root.appending(path: "Runtime/bin", directoryHint: .isDirectory)
	try fileManager.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true)
	let trace = root.appending(path: "commands.log")
	let script = """
		#!/bin/sh
		printf '%s\\n' "$1" >> '\(trace.path)'
		if [ "$1" = "-k" ]; then exit \(killStatus); fi
		exit \(waitStatus)
		"""
	let wineserver = runtimeDirectory.appending(path: "wineserver")
	try Data(script.utf8).write(to: wineserver)
	try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wineserver.path)
	let runtime = WineRuntime(
		executableURL: runtimeDirectory.appending(path: "Arknights"),
		displayName: "Fixture",
		revision: "fixture",
		compatibilityManager: GameCompatibilityManager(active: [])
	)
	return WineserverStatusFixture(
		runtime: runtime,
		prefixDirectory: root.appending(path: "prefix", directoryHint: .isDirectory),
		trace: trace
	)
}

private struct LaunchFixture {
	let root: URL
	let runtime: WineRuntime
	let prefixDirectory: URL
	let gameExecutable: URL
	let logURL: URL
	let spawnMarker: URL
	let helperSpawnMarker: URL
}

private func makeLaunchFixture(pendingRegistryMigration: Bool = false) throws -> LaunchFixture {
	let fileManager = FileManager.default
	let root = fileManager.temporaryDirectory.appending(
		path: "wine-launch-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
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
	for architecture in ["x64"] {
		let payloadDirectory = runtimeRoot.appending(
			path: "DXMT/\(architecture)",
			directoryHint: .isDirectory
		)
		try fileManager.createDirectory(at: payloadDirectory, withIntermediateDirectories: true)
		for library in WineRuntime.dxmtLibraryNames {
			try Data("fixture".utf8).write(to: payloadDirectory.appending(path: library))
		}
	}
	let runtime = WineRuntime(
		executableURL: executable,
		displayName: "Fixture",
		revision: "fixture",
		compatibilityManager: GameCompatibilityManager(active: [])
	)
	return LaunchFixture(
		root: root,
		runtime: runtime,
		prefixDirectory: prefixDirectory,
		gameExecutable: gameExecutable,
		logURL: root.appending(path: "Logs/game.log"),
		spawnMarker: spawnMarker,
		helperSpawnMarker: helperSpawnMarker
	)
}
