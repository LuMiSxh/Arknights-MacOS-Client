// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import Foundation

extension WineRuntime {
	/// Creates the directories Wine and the isolated profile need. Launch and the background
	/// refresh share it so both prepare a prefix identically.
	static func ensurePrefixSkeleton(at prefixDirectory: URL, fileManager: FileManager) throws {
		try fileManager.createDirectory(at: prefixDirectory, withIntermediateDirectories: true)
		try fileManager.createDirectory(
			at: prefixDirectory.appending(path: "home", directoryHint: .isDirectory),
			withIntermediateDirectories: true
		)
		for directory in isolatedEnvironmentDirectories(prefixDirectory: prefixDirectory) {
			try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
		}
		try writeIsolatedUserDirectoryConfiguration(
			prefixDirectory: prefixDirectory,
			fileManager: fileManager
		)
	}

	/// Opens the publisher's runtime log for appending, creating it when missing.
	static func openRuntimeLog(at logURL: URL, fileManager: FileManager) throws -> FileHandle {
		try fileManager.createDirectory(
			at: logURL.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		if !fileManager.fileExists(atPath: logURL.path) {
			guard fileManager.createFile(atPath: logURL.path, contents: nil) else {
				throw InstallerError.cannotCreateFile(logURL)
			}
		}
		let handle = try FileHandle(forWritingTo: logURL)
		try handle.seekToEnd()
		return handle
	}

	/// Runs the regular prefix migration for an existing prefix without starting the game.
	/// Returns false when nothing was pending. The prefix-wide shutdown always completes, also
	/// when the caller cancels, so no Wine process outlives the call.
	@concurrent
	func refreshPrefixIfPending(
		at prefixDirectory: URL,
		gameDirectory: URL,
		logURL: URL,
		log: LauncherLog?,
		spawnGate: WineProcessSpawnGate
	) async throws -> Bool {
		guard try hasPendingMigration(prefixDirectory: prefixDirectory) else { return false }
		let fileManager = FileManager.default
		try Self.ensurePrefixSkeleton(at: prefixDirectory, fileManager: fileManager)
		let logHandle = try Self.openRuntimeLog(at: logURL, fileManager: fileManager)
		defer { logHandle.closeFile() }
		var environment = runtimeEnvironment(prefixDirectory: prefixDirectory, frameRateLimit: nil)
		environment["WINEDLLOVERRIDES"] = Self.dllOverrides
		let migration: Result<Void, any Error>
		do {
			try await preparePrefixIfNeeded(
				at: prefixDirectory,
				gameDirectory: gameDirectory,
				logsDirectory: logURL.deletingLastPathComponent(),
				environment: environment,
				logHandle: logHandle,
				log: log,
				spawnGate: spawnGate
			)
			migration = .success(())
		} catch {
			migration = .failure(error)
		}
		// An unstructured task does not inherit cancellation, so `wineserver -k` and `-w` still run.
		let shutdown = await Task {
			try await stop(prefixDirectory: prefixDirectory, spawnGate: spawnGate)
		}.result
		try migration.get()
		try shutdown.get()
		return true
	}
}
