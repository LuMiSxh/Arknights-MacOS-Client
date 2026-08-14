// SPDX-License-Identifier: MPL-2.0

import Foundation

struct WineRuntime: Sendable {
	let executableURL: URL
	let displayName: String
	let usesDXMT: Bool

	static func discover(
		bundle: Bundle = .main,
		fileManager: FileManager = .default
	) -> WineRuntime? {
		guard let resources = bundle.resourceURL else { return nil }
		let candidates = [
			resources.appending(path: "Runtime/bin/wine64"),
			resources.appending(path: "Runtime/bin/wine"),
		]

		for executable in candidates where fileManager.isExecutableFile(atPath: executable.path) {
			return WineRuntime(
				executableURL: executable,
				displayName: "Bundled Wine + DXMT",
				usesDXMT: true
			)
		}
		return nil
	}

	func launch(
		gameExecutable: URL,
		prefixDirectory: URL,
		gameArguments: [String] = [],
		logURL: URL? = nil
	) async throws -> Int32 {
		let fileManager = FileManager.default
		try fileManager.createDirectory(at: prefixDirectory, withIntermediateDirectories: true)
		var mutablePrefixDirectory = prefixDirectory
		var prefixValues = URLResourceValues()
		prefixValues.isExcludedFromBackup = true
		try? mutablePrefixDirectory.setResourceValues(prefixValues)
		let logURL =
			logURL ?? prefixDirectory.deletingLastPathComponent().appending(path: "wine.log")
		try fileManager.createDirectory(
			at: logURL.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		if !fileManager.fileExists(atPath: logURL.path) {
			guard fileManager.createFile(atPath: logURL.path, contents: nil) else {
				throw LauncherError.cannotCreateFile(logURL)
			}
		}
		let logHandle = try FileHandle(forWritingTo: logURL)
		try logHandle.seekToEnd()

		var environment = ProcessInfo.processInfo.environment
		environment["WINEPREFIX"] = prefixDirectory.path
		environment["WINEDEBUG"] = "-all"
		environment["WINEDLLOVERRIDES"] = "mscoree,mshtml="
		environment["PATH"] = [
			executableURL.deletingLastPathComponent().path,
			"/opt/homebrew/bin",
			"/usr/local/bin",
			"/usr/bin",
			"/bin",
		].joined(separator: ":")

		try await preparePrefixIfNeeded(
			at: prefixDirectory,
			environment: environment,
			logHandle: logHandle
		)

		let process = Process()
		process.executableURL = executableURL
		process.arguments = [gameExecutable.path] + gameArguments
		process.currentDirectoryURL = gameExecutable.deletingLastPathComponent()
		process.environment = environment
		process.standardOutput = logHandle
		process.standardError = logHandle
		try process.run()
		do {
			try logHandle.close()
		} catch {
			// The child process owns its duplicated descriptor after launch.
		}
		// Keep the launcher in its startup phase long enough to catch early Unity or runtime failures.
		try await Task.sleep(for: .seconds(12))
		if !process.isRunning, process.terminationStatus != 0 {
			throw LauncherError.runtimeExited(status: process.terminationStatus, log: logURL)
		}
		return process.processIdentifier
	}

	private func preparePrefixIfNeeded(
		at prefixDirectory: URL,
		environment: [String: String],
		logHandle: FileHandle
	) async throws {
		guard usesDXMT else { return }

		let fileManager = FileManager.default
		let systemRegistry = prefixDirectory.appending(path: "system.reg")
		if !fileManager.fileExists(atPath: systemRegistry.path) {
			let winebootURL = executableURL.deletingLastPathComponent().appending(path: "wineboot")
			guard fileManager.isExecutableFile(atPath: winebootURL.path) else {
				throw LauncherError.runtimeConfiguration(
					"wineboot is missing from the bundled runtime.")
			}

			let exitStatus = try await runAndWait(
				executable: winebootURL,
				arguments: ["-u"],
				environment: environment,
				output: logHandle
			)
			guard exitStatus == 0 else {
				throw LauncherError.runtimeConfiguration(
					"Wine could not initialize its prefix (status \(exitStatus))."
				)
			}
		}

		let runtimeRoot = executableURL.deletingLastPathComponent().deletingLastPathComponent()
		let source = runtimeRoot.appending(path: "lib/wine/x86_64-windows/winemetal.dll")
		let destination = prefixDirectory.appending(path: "drive_c/windows/system32/winemetal.dll")
		guard fileManager.fileExists(atPath: source.path) else {
			throw LauncherError.runtimeConfiguration("The DXMT Wine bridge is missing.")
		}

		try fileManager.createDirectory(
			at: destination.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		if !filesMatch(source, destination, fileManager: fileManager) {
			if fileManager.fileExists(atPath: destination.path) {
				try fileManager.removeItem(at: destination)
			}
			try fileManager.copyItem(at: source, to: destination)
		}
	}

	private func filesMatch(_ lhs: URL, _ rhs: URL, fileManager: FileManager) -> Bool {
		guard
			let lhsValues = try? lhs.resourceValues(forKeys: [
				.fileSizeKey, .contentModificationDateKey,
			]),
			let rhsValues = try? rhs.resourceValues(forKeys: [
				.fileSizeKey, .contentModificationDateKey,
			])
		else {
			return false
		}
		return lhsValues.fileSize == rhsValues.fileSize
			&& lhsValues.contentModificationDate == rhsValues.contentModificationDate
	}

	private func runAndWait(
		executable: URL,
		arguments: [String],
		environment: [String: String],
		output: FileHandle
	) async throws -> Int32 {
		try await withCheckedThrowingContinuation { continuation in
			let process = Process()
			process.executableURL = executable
			process.arguments = arguments
			process.environment = environment
			process.standardOutput = output
			process.standardError = output
			process.terminationHandler = { process in
				continuation.resume(returning: process.terminationStatus)
			}
			do {
				try process.run()
			} catch {
				continuation.resume(throwing: error)
			}
		}
	}
}
