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
func wineProcessWaiterDeadlineRetiresTheHelperWait() async {
	let waiter = WineProcessWaiter(
		executable: URL(filePath: "/bin/sleep"),
		arguments: ["30"],
		environment: [:],
		output: .nullDevice,
		terminationGracePeriod: .milliseconds(50)
	)
	let clock = ContinuousClock()
	let started = clock.now
	var didTimeOut = false
	do {
		_ = try await waiter.wait(timeout: .milliseconds(25))
	} catch {
		didTimeOut = true
	}

	#expect(didTimeOut)
	#expect(started.duration(to: clock.now) < .seconds(1))
}

@Test
func wineProcessWaiterEscalatesWhenATimedOutHelperIgnoresTerminate() async throws {
	let root = FileManager.default.temporaryDirectory.appending(
		path: "wine-helper-kill-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
	defer { try? FileManager.default.removeItem(at: root) }
	let fifo = root.appending(path: "block")
	let started = root.appending(path: "started")
	let pidFile = root.appending(path: "pid")
	let fifoStatus = fifo.path.withCString { Darwin.mkfifo($0, 0o600) }
	#expect(fifoStatus == 0)
	let script = """
		trap '' TERM
		printf '%s\\n' "$$" > '\(pidFile.path)'
		: > '\(started.path)'
		read ignored < '\(fifo.path)'
		"""
	let waiter = WineProcessWaiter(
		executable: URL(filePath: "/bin/sh"),
		arguments: ["-c", script],
		environment: [:],
		output: .nullDevice,
		terminationGracePeriod: .milliseconds(50)
	)
	let wait = Task { try await waiter.wait(timeout: .milliseconds(500)) }
	let helperStarted = await waitForFixtureFile(started, timeout: .seconds(1))
	#expect(helperStarted)
	guard helperStarted else {
		_ = try? await wait.value
		return
	}
	do {
		_ = try await wait.value
		Issue.record("A blocked helper unexpectedly completed before its timeout.")
	} catch is WineProcessWaitTimeout {
	} catch {
		Issue.record("The blocked helper produced an unexpected error: \(error)")
	}
	let pidText = try String(contentsOf: pidFile, encoding: .utf8)
	let pid = pid_t(pidText.trimmingCharacters(in: .whitespacesAndNewlines))!
	#expect(await waitForProcessExit(pid, timeout: .seconds(1)))
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
	model.lifecycle.activity = .launchingGame(
		sessionID: sessionID,
		processIdentifier: nil
	)
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

private func waitForProcessExit(_ processIdentifier: pid_t, timeout: Duration) async -> Bool {
	let clock = ContinuousClock()
	let deadline = clock.now.advanced(by: timeout)
	while clock.now < deadline {
		if Darwin.kill(processIdentifier, 0) != 0, errno == ESRCH { return true }
		try? await Task.sleep(for: .milliseconds(10))
	}
	return Darwin.kill(processIdentifier, 0) != 0 && errno == ESRCH
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
	for architecture in ["x64", "x32"] {
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
