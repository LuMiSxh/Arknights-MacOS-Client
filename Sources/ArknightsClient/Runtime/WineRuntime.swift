// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

struct WineLaunch: Sendable {
	let processIdentifier: Int32
	private let terminationTask: Task<Int32, Never>

	init(processIdentifier: Int32, terminationTask: Task<Int32, Never>) {
		self.processIdentifier = processIdentifier
		self.terminationTask = terminationTask
	}

	func waitUntilExit() async -> Int32 {
		await terminationTask.value
	}
}

struct RuntimeConfiguration: Decodable, Sendable {
	struct Archive: Decodable, Sendable {
		let sha256: String
	}

	let prefixRevision: Int
	let runtime: Archive

	var revision: String {
		"\(runtime.sha256)-prefix-\(prefixRevision)"
	}
}

struct WineRuntime: Sendable {
	let executableURL: URL
	let displayName: String
	let revision: String

	static let dllOverrides =
		"d3d10core,d3d11,dxgi=n,b;winemetal=b;dcomp,mscoree,mshtml="
	static let debugChannels = "-all,err+all"
	static let synchronizationEnvironment = ["WINEESYNC": "1"]
	static let globalRegistryOverrides = [
		"d3d10core": "native,builtin",
		"d3d11": "native,builtin",
		"dxgi": "native,builtin",
		"winemetal": "builtin",
		"dcomp": "",
		"mscoree": "",
		"mshtml": "",
	]
	static let inheritedEnvironmentKeys = ["LANG", "LC_ALL", "LC_CTYPE", "__CF_USER_TEXT_ENCODING"]
	static let dxmtLibraryNames = ["d3d10core.dll", "d3d11.dll", "dxgi.dll", "winemetal.dll"]
	static let crashDialogRegistryKey = "HKCU\\Software\\Wine\\WineDbg"
	static let crashDialogRegistryValue = "ShowCrashDialog"
	static let macDriverRegistryKey = "HKCU\\Software\\Wine\\Mac Driver"
	static let preciseScrollingRegistryValue = "UsePreciseScrolling"
	static let leftCommandIsCtrlRegistryValue = "LeftCommandIsCtrl"
	static let rightCommandIsCtrlRegistryValue = "RightCommandIsCtrl"
	static let isolatedUserDirectoryNames = [
		"Desktop", "Documents", "Downloads", "Music", "Pictures", "Movies", "Templates",
	]

	static func discover(
		bundle: Bundle = .main,
		fileManager: FileManager = .default
	) -> WineRuntime? {
		guard let resources = bundle.resourceURL else { return nil }
		let executable = resources.appending(path: "Runtime/bin/Arknights")
		guard fileManager.isExecutableFile(atPath: executable.path) else { return nil }
		let configurationURL = resources.appending(path: "RUNTIME.json")
		guard
			let data = try? Data(contentsOf: configurationURL),
			let configuration = try? JSONDecoder().decode(RuntimeConfiguration.self, from: data),
			configuration.prefixRevision > 0,
			!configuration.runtime.sha256.isEmpty
		else {
			return nil
		}
		return WineRuntime(
			executableURL: executable,
			displayName: "Bundled Wine + DXMT",
			revision: configuration.revision
		)
	}

	func launch(
		gameExecutable: URL,
		prefixDirectory: URL,
		gameArguments: [String] = [],
		displayConfiguration: WineDisplayConfiguration,
		graphicsDiagnostics: Bool = false,
		logURL: URL? = nil,
		log: LauncherLog? = nil
	) async throws -> WineLaunch {
		let launchStarted = ContinuousClock.now
		let fileManager = FileManager.default
		try fileManager.createDirectory(at: prefixDirectory, withIntermediateDirectories: true)
		try fileManager.createDirectory(
			at: prefixDirectory.appending(path: "home", directoryHint: .isDirectory),
			withIntermediateDirectories: true
		)
		for directory in Self.isolatedEnvironmentDirectories(prefixDirectory: prefixDirectory) {
			try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
		}
		try Self.writeIsolatedUserDirectoryConfiguration(
			prefixDirectory: prefixDirectory,
			fileManager: fileManager
		)
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
		RuntimePerformanceLog.write(stage: "filesystem", since: launchStarted, to: logHandle)
		let compatibilityChanges = try GameCompatibilityManager().prepareForLaunch(
			in: gameExecutable.deletingLastPathComponent()
		)
		RuntimePerformanceLog.write(stage: "compatibility", since: launchStarted, to: logHandle)
		for identifier in compatibilityChanges.installed {
			try? logHandle.write(
				contentsOf: Data(
					"Arknights Client: enabled compatibility component \(identifier).\n".utf8
				))
		}
		for identifier in compatibilityChanges.removed {
			try? logHandle.write(
				contentsOf: Data(
					"Arknights Client: removed retired compatibility component \(identifier).\n"
						.utf8
				))
		}

		var environment = runtimeEnvironment(
			prefixDirectory: prefixDirectory,
			graphicsDiagnostics: graphicsDiagnostics
		)
		environment["WINEDLLOVERRIDES"] = Self.dllOverrides
		try await preparePrefixIfNeeded(
			at: prefixDirectory,
			gameDirectory: gameExecutable.deletingLastPathComponent(),
			environment: environment,
			logHandle: logHandle,
			log: log
		)
		RuntimePerformanceLog.write(stage: "prefix", since: launchStarted, to: logHandle)
		environment.removeValue(forKey: "WINEDLLOVERRIDES")
		try await applyDisplayConfiguration(
			displayConfiguration,
			prefixDirectory: prefixDirectory,
			environment: environment,
			logHandle: logHandle
		)
		RuntimePerformanceLog.write(stage: "display", since: launchStarted, to: logHandle)
		environment["ARKNIGHTS_CLIENT_BROWSER_SCALE_FACTOR"] = String(
			displayConfiguration.browserScaleFactor
		)

		let process = Process()
		process.executableURL = executableURL
		process.arguments = [Self.windowsGamePath(for: gameExecutable)] + gameArguments
		process.currentDirectoryURL = gameExecutable.deletingLastPathComponent()
		process.environment = environment
		process.standardOutput = logHandle
		process.standardError = logHandle
		let (terminationStatuses, terminationContinuation) = AsyncStream<Int32>.makeStream(
			bufferingPolicy: .bufferingNewest(1)
		)
		process.terminationHandler = { process in
			terminationContinuation.yield(process.terminationStatus)
			terminationContinuation.finish()
		}
		try process.run()
		RuntimePerformanceLog.write(stage: "process", since: launchStarted, to: logHandle)
		try? logHandle.close()

		let terminationTask = Task {
			for await status in terminationStatuses { return status }
			return 0
		}
		return WineLaunch(
			processIdentifier: process.processIdentifier,
			terminationTask: terminationTask
		)
	}

	static func windowsGamePath(for executable: URL) -> String {
		"G:\\" + executable.lastPathComponent
	}

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
		guard let wineserverURL else {
			throw LauncherError.runtimeConfiguration(
				"wineserver is missing from the bundled runtime.")
		}
		let status = try await runAndWait(
			executable: wineserverURL,
			arguments: ["-k"],
			environment: runtimeEnvironment(prefixDirectory: prefixDirectory),
			output: .nullDevice
		)
		guard status == 0 else {
			throw LauncherError.runtimeConfiguration(
				"Wine could not stop Arknights (status \(status)).")
		}
	}

	func stopSynchronously(prefixDirectory: URL) {
		guard let wineserverURL else { return }
		let process = Process()
		process.executableURL = wineserverURL
		process.arguments = ["-k"]
		process.environment = runtimeEnvironment(prefixDirectory: prefixDirectory)
		process.standardOutput = FileHandle.nullDevice
		process.standardError = FileHandle.nullDevice
		let terminated = DispatchSemaphore(value: 0)
		process.terminationHandler = { _ in terminated.signal() }
		guard (try? process.run()) != nil else { return }
		guard terminated.wait(timeout: .now() + 3) == .timedOut else { return }
		process.terminate()
		guard terminated.wait(timeout: .now() + 1) == .timedOut else { return }
		Darwin.kill(process.processIdentifier, SIGKILL)
	}

	var wineserverURL: URL? {
		let candidate = executableURL.deletingLastPathComponent().appending(path: "wineserver")
		return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
	}

	func runAndWait(
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
