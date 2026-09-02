// SPDX-License-Identifier: MPL-2.0

import Foundation

struct WineProcessExit: Sendable {
	let status: Int32
	let reason: Process.TerminationReason
}

struct WineLaunch: Sendable {
	let processIdentifier: Int32
	private let terminationTask: Task<WineProcessExit, Never>

	init(processIdentifier: Int32, terminationTask: Task<WineProcessExit, Never>) {
		self.processIdentifier = processIdentifier
		self.terminationTask = terminationTask
	}

	func waitUntilExit() async -> WineProcessExit {
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

/// The bundled Wine + DXMT build, discovered from `RUNTIME.json` in the app's resources, and
/// the single entry point for launching, monitoring, and stopping the Windows game process.
struct WineRuntime: Sendable {
	let executableURL: URL
	let displayName: String
	let revision: String
	let gameIconBridgeURL: URL?
	private let compatibilityManager: GameCompatibilityManager

	init(
		executableURL: URL,
		displayName: String,
		revision: String,
		gameIconBridgeURL: URL? = nil,
		compatibilityManager: GameCompatibilityManager
	) {
		self.executableURL = executableURL
		self.displayName = displayName
		self.revision = revision
		self.gameIconBridgeURL = gameIconBridgeURL
		self.compatibilityManager = compatibilityManager
	}

	static let dllOverrides =
		"d3d10core,d3d11,dxgi=n,b;winemetal=b;dcomp,mscoree,mshtml="
	static let debugChannels = "-all,err+all"
	static func synchronizationEnvironment(
		for mode: WineSynchronizationMode
	) -> [String: String] {
		switch mode {
		case .msync: ["WINEMSYNC": "1"]
		case .esync: ["WINEESYNC": "1"]
		}
	}
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
	static let normalizedScrollingRegistryData = "n"
	static let leftCommandIsCtrlRegistryValue = "LeftCommandIsCtrl"
	static let rightCommandIsCtrlRegistryValue = "RightCommandIsCtrl"
	static let isolatedUserDirectoryNames = [
		"Desktop", "Documents", "Downloads", "Music", "Pictures", "Movies", "Templates",
	]

	static func discover(
		bundle: Bundle = .main,
		fileManager: FileManager = .default,
		compatibilityManager: GameCompatibilityManager
	) throws -> WineRuntime {
		guard let resources = bundle.resourceURL else {
			throw WineRuntimeDiscoveryError.missingResourceDirectory
		}
		let executable = resources.appending(path: "Runtime/bin/Arknights")
		guard fileManager.isExecutableFile(atPath: executable.path) else {
			throw WineRuntimeDiscoveryError.missingExecutable(executable)
		}
		let configurationURL = resources.appending(path: "RUNTIME.json")
		let data: Data
		do {
			data = try Data(contentsOf: configurationURL)
		} catch {
			throw WineRuntimeDiscoveryError.unreadableConfiguration(
				configurationURL,
				error.localizedDescription
			)
		}
		let configuration: RuntimeConfiguration
		do {
			configuration = try JSONDecoder().decode(RuntimeConfiguration.self, from: data)
		} catch {
			throw WineRuntimeDiscoveryError.invalidConfiguration(
				configurationURL,
				error.localizedDescription
			)
		}
		guard configuration.prefixRevision > 0 else {
			throw WineRuntimeDiscoveryError.invalidConfiguration(
				configurationURL,
				"prefixRevision must be greater than zero"
			)
		}
		guard !configuration.runtime.sha256.isEmpty else {
			throw WineRuntimeDiscoveryError.invalidConfiguration(
				configurationURL,
				"runtime.sha256 must not be empty"
			)
		}
		return WineRuntime(
			executableURL: executable,
			displayName: "Bundled Wine + DXMT",
			revision: configuration.revision,
			gameIconBridgeURL: resources.appending(
				path: "Compatibility/GameIcon/GameIconBridge.dylib"
			),
			compatibilityManager: compatibilityManager
		)
	}

	func launch(
		gameExecutable: URL,
		prefixDirectory: URL,
		gameArguments: [String] = [],
		displayConfiguration: WineDisplayConfiguration,
		graphicsDiagnostics: Bool = false,
		metalPerformanceHUDEnabled: Bool = false,
		synchronizationMode: WineSynchronizationMode = .msync,
		runtimeEnvironmentOverrides: [String: String] = [:],
		gameIconURL: URL? = nil,
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
		do {
			try mutablePrefixDirectory.setResourceValues(prefixValues)
		} catch {
			await log?.error(
				"Failed to exclude the Wine prefix from backups: \(error.localizedDescription)"
			)
		}

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
		defer { logHandle.closeFile() }
		try logHandle.seekToEnd()
		RuntimePerformanceLog.write(
			stage: "filesystem", since: launchStarted, to: logHandle)
		let compatibilityChanges = try compatibilityManager.prepareForLaunch(
			in: gameExecutable.deletingLastPathComponent()
		)
		for identifier in compatibilityChanges.installed {
			try? logHandle.write(
				contentsOf: Data(
					"Arknights Client: enabled compatibility component \(identifier).\n".utf8))
		}
		for identifier in compatibilityChanges.removed {
			try? logHandle.write(
				contentsOf: Data(
					"Arknights Client: removed retired compatibility component \(identifier).\n"
						.utf8))
		}
		RuntimePerformanceLog.write(
			stage: "compatibility", since: launchStarted, to: logHandle)

		var environment = runtimeEnvironment(
			prefixDirectory: prefixDirectory,
			graphicsDiagnostics: graphicsDiagnostics,
			synchronizationMode: synchronizationMode
		)
		environment.merge(runtimeEnvironmentOverrides) { _, value in value }
		environment["WINEDLLOVERRIDES"] = Self.dllOverrides
		try await preparePrefixIfNeeded(
			at: prefixDirectory,
			gameDirectory: gameExecutable.deletingLastPathComponent(),
			logsDirectory: logURL.deletingLastPathComponent(),
			environment: environment,
			logHandle: logHandle,
			log: log
		)
		RuntimePerformanceLog.write(
			stage: "prefix", since: launchStarted, to: logHandle)
		environment.removeValue(forKey: "WINEDLLOVERRIDES")
		try await applyDisplayConfiguration(
			displayConfiguration,
			prefixDirectory: prefixDirectory,
			environment: environment,
			logHandle: logHandle
		)
		RuntimePerformanceLog.write(
			stage: "display", since: launchStarted, to: logHandle)
		environment["ARKNIGHTS_CLIENT_BROWSER_SCALE_FACTOR"] = String(
			displayConfiguration.browserScaleFactor
		)
		if metalPerformanceHUDEnabled {
			environment["MTL_HUD_ENABLED"] = "1"
		}
		for (key, value) in gameIconEnvironment(customIconURL: gameIconURL) {
			environment[key] = value
		}

		let process = Process()
		process.executableURL = executableURL
		process.arguments = [Self.windowsGamePath(for: gameExecutable)] + gameArguments
		process.currentDirectoryURL = gameExecutable.deletingLastPathComponent()
		process.environment = environment
		process.standardOutput = logHandle
		process.standardError = logHandle
		let (terminationStatuses, terminationContinuation) = AsyncStream<WineProcessExit>
			.makeStream(
				bufferingPolicy: .bufferingNewest(1)
			)
		process.terminationHandler = { process in
			terminationContinuation.yield(
				WineProcessExit(
					status: process.terminationStatus, reason: process.terminationReason)
			)
			terminationContinuation.finish()
		}
		try process.run()
		RuntimePerformanceLog.write(
			stage: "process", since: launchStarted, to: logHandle)

		let terminationTask = Task {
			for await exit in terminationStatuses { return exit }
			return WineProcessExit(status: 0, reason: .exit)
		}
		return WineLaunch(
			processIdentifier: process.processIdentifier,
			terminationTask: terminationTask
		)
	}

	static func windowsGamePath(for executable: URL) -> String {
		"G:\\" + executable.lastPathComponent
	}

}
