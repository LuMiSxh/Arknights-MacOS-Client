// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
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

/// The installed Wine + DXMT build, discovered from the managed runtime's `RUNTIME.json`, and
/// the single entry point for launching, monitoring, and stopping the Windows game process.
struct WineRuntime: Sendable {
	struct DXMTDestination: Sendable, Equatable {
		let architecture: String
		let windowsDirectory: String
	}

	let executableURL: URL
	let displayName: String
	let revision: String
	let runtimeArchitecture: String
	let lane: RuntimeLane?
	let dxmtPayloadDirectory: String
	let dxmtPayloadDestinations: [DXMTDestination]
	let dxmtPayloadLibraries: [String]
	let gameIconBridgeURL: URL?
	// Candidate loader bundles in priority order; empty when the lane has none.
	let loaderBundleURLs: [URL]
	let features: RuntimeFeatures
	let pins: RuntimePins
	private let compatibilityManager: GameCompatibilityManager

	init(
		executableURL: URL,
		displayName: String,
		revision: String,
		runtimeArchitecture: String = "Unknown",
		lane: RuntimeLane? = nil,
		dxmtPayloadDirectory: String = WineRuntime.defaultDXMTPayloadDirectory,
		dxmtPayloadDestinations: [DXMTDestination] = WineRuntime.dxmtDestinations,
		dxmtPayloadLibraries: [String] = WineRuntime.dxmtLibraryNames,
		gameIconBridgeURL: URL? = nil,
		loaderBundleURLs: [URL] = [],
		features: RuntimeFeatures = .conservative,
		pins: RuntimePins = RuntimePins(),
		compatibilityManager: GameCompatibilityManager
	) {
		self.executableURL = executableURL
		self.displayName = displayName
		self.revision = revision
		self.runtimeArchitecture = runtimeArchitecture
		self.lane = lane
		self.dxmtPayloadDirectory = dxmtPayloadDirectory
		self.dxmtPayloadDestinations = dxmtPayloadDestinations
		self.dxmtPayloadLibraries = dxmtPayloadLibraries
		self.gameIconBridgeURL = gameIconBridgeURL
		self.loaderBundleURLs = loaderBundleURLs
		self.features = features
		self.pins = pins
		self.compatibilityManager = compatibilityManager
	}

	var isNativeARMLane: Bool { lane == .arm }

	static let dllOverrides =
		"d3d10core,d3d11,dxgi=n,b;winemetal=b;dcomp,mscoree,mshtml="
	static let winebootDLLOverride = "winemac.drv=d"
	static let debugChannels = "-all,err+all"
	static let verboseDebugChannels =
		"+timestamp,+pid,-all,err+all,warn+module,+seh,+process,+exec,+loaddll,+winebrowser,+win,+system,+explorer,+macdrv"
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
	// Earlier builds shipped 32-bit DXMT files. `removeLegacy32BitLibraries` cleans them up
	// once the runtime stops shipping `i386-windows`.
	static let dxmtDestinations = [
		DXMTDestination(architecture: "x64", windowsDirectory: "system32")
	]
	static let dxmtLibraryNames = ["d3d10core.dll", "d3d11.dll", "dxgi.dll", "winemetal.dll"]
	static let defaultDXMTPayloadDirectory = "DXMT"
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
		runtimeRoot: URL,
		configurationURL: URL,
		fileManager: FileManager = .default,
		compatibilityManager: GameCompatibilityManager
	) throws -> WineRuntime {
		let bridge = Bundle.main.resourceURL?.appending(
			path: "Compatibility/GameIcon/GameIconBridge.dylib")
		return try discover(
			runtimeRoot: runtimeRoot,
			configurationURL: configurationURL,
			gameIconBridgeURL: bridge,
			fileManager: fileManager,
			compatibilityManager: compatibilityManager
		)
	}

	private static func discover(
		runtimeRoot: URL,
		configurationURL: URL,
		gameIconBridgeURL: URL?,
		fileManager: FileManager,
		compatibilityManager: GameCompatibilityManager
	) throws -> WineRuntime {
		let executable = runtimeRoot.appending(path: "bin/Arknights")
		guard fileManager.isExecutableFile(atPath: executable.path) else {
			throw WineRuntimeDiscoveryError.missingExecutable(executable)
		}
		let manifest: RuntimeManifest
		do {
			let data = try Data(contentsOf: configurationURL)
			manifest = try JSONDecoder().decode(RuntimeManifest.self, from: data)
		} catch let error as DecodingError {
			throw WineRuntimeDiscoveryError.invalidConfiguration(
				configurationURL, error.localizedDescription
			)
		} catch {
			throw WineRuntimeDiscoveryError.unreadableConfiguration(
				configurationURL, error.localizedDescription
			)
		}
		guard manifest.prefixRevision > 0 else {
			throw WineRuntimeDiscoveryError.invalidConfiguration(
				configurationURL,
				"prefixRevision must be greater than zero"
			)
		}
		guard !manifest.runtime.sha256.isEmpty else {
			throw WineRuntimeDiscoveryError.invalidConfiguration(
				configurationURL,
				"runtime.sha256 must not be empty"
			)
		}
		let dxmtLibraries = manifest.interface.dxmt.libraries
		let dxmtDestinations =
			manifest.interface.dxmt.destinations.map {
				DXMTDestination(architecture: $0.key, windowsDirectory: $0.value)
			}.sorted { $0.architecture < $1.architecture }
		guard !dxmtLibraries.isEmpty, dxmtLibraries.allSatisfy(Self.isSafeDXMTComponent) else {
			throw WineRuntimeDiscoveryError.invalidConfiguration(
				configurationURL,
				"interface.dxmt.libraries must be a non-empty list of file names"
			)
		}
		guard
			Self.isSafeDXMTComponent(manifest.interface.dxmt.payloadDirectory)
		else {
			throw WineRuntimeDiscoveryError.invalidConfiguration(
				configurationURL,
				"interface.dxmt.payloadDirectory must be a path component"
			)
		}
		guard
			!dxmtDestinations.isEmpty,
			dxmtDestinations.allSatisfy({
				Self.isSafeDXMTComponent($0.architecture)
					&& Self.isSafeDXMTComponent($0.windowsDirectory)
			})
		else {
			throw WineRuntimeDiscoveryError.invalidConfiguration(
				configurationURL,
				"interface.dxmt.destinations must be non-empty path components"
			)
		}
		return WineRuntime(
			executableURL: executable,
			displayName: manifest.runtime.name,
			revision: manifest.revision,
			runtimeArchitecture: manifest.architecture.label,
			lane: manifest.architecture,
			dxmtPayloadDirectory: manifest.interface.dxmt.payloadDirectory,
			dxmtPayloadDestinations: dxmtDestinations,
			dxmtPayloadLibraries: dxmtLibraries,
			gameIconBridgeURL: gameIconBridgeURL,
			loaderBundleURLs: manifest.architecture == .arm
				? manifest.interface.loaderPaths.map { runtimeRoot.appending(path: $0) } : [],
			features: manifest.interface.features,
			pins: RuntimePins(
				wineVersion: manifest.components?.wine,
				wineCommit: manifest.provenance?.wineCommit,
				dxmtVersion: manifest.components?.dxmt,
				dxmtCommit: manifest.provenance?.dxmtCommit
			),
			compatibilityManager: compatibilityManager
		)
	}

	static func isSafeDXMTComponent(_ value: String) -> Bool {
		!value.isEmpty
			&& value != "."
			&& value != ".."
			&& !value.contains("/")
			&& !value.contains("\\")
			&& !value.utf8.contains(0)
	}

	@concurrent
	func launch(
		gameExecutable: URL,
		prefixDirectory: URL,
		gameArguments: [String] = [],
		displayConfiguration: WineDisplayConfiguration,
		graphicsDiagnostics: Bool = false,
		debugLogging: Bool = false,
		metalPerformanceHUDEnabled: Bool = false,
		synchronizationMode: WineSynchronizationMode = .msync,
		frameRateLimit: GameFrameRateLimit,
		runtimeEnvironmentOverrides: [String: String] = [:],
		clientVariant: GameClientVariant = .standard,
		publisher: GamePublisher = .yostar,
		gameIconURL: URL? = nil,
		logURL: URL? = nil,
		log: LauncherLog? = nil,
		spawnGate: WineProcessSpawnGate = WineProcessSpawnGate()
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
			log?.error(
				"Failed to exclude the Wine prefix from backups: \(error.localizedDescription)"
			)
		}

		let logURL =
			logURL
			?? prefixDirectory.deletingLastPathComponent().appending(
				path: publisher.runtimeLogFileName
			)
		try fileManager.createDirectory(
			at: logURL.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		if !fileManager.fileExists(atPath: logURL.path) {
			guard fileManager.createFile(atPath: logURL.path, contents: nil) else {
				throw InstallerError.cannotCreateFile(logURL)
			}
		}
		let logHandle = try FileHandle(forWritingTo: logURL)
		defer { logHandle.closeFile() }
		try logHandle.seekToEnd()
		RuntimePerformanceLog.write(
			stage: "filesystem", since: launchStarted, to: logHandle, log: log)
		let compatibilityChanges: GameCompatibilityChanges
		do {
			compatibilityChanges = try compatibilityManager.prepareForLaunch(
				in: gameExecutable.deletingLastPathComponent()
			)
		} catch {
			throw GameRuntimeError.mappingCompatibilityFailure(error)
		}
		for identifier in compatibilityChanges.installed {
			logHandle.appendLaunchLogLine(
				"Arknights Client: enabled compatibility component \(identifier).\n", log: log)
		}
		for identifier in compatibilityChanges.removed {
			logHandle.appendLaunchLogLine(
				"Arknights Client: removed retired compatibility component \(identifier).\n",
				log: log)
		}
		RuntimePerformanceLog.write(
			stage: "compatibility", since: launchStarted, to: logHandle, log: log)

		var environment = runtimeEnvironment(
			prefixDirectory: prefixDirectory,
			graphicsDiagnostics: graphicsDiagnostics,
			frameRateLimit: frameRateLimit,
			synchronizationMode: synchronizationMode,
			debugLogging: debugLogging
		)
		environment.merge(runtimeEnvironmentOverrides) { _, value in value }
		if clientVariant == .bilibili {
			environment["LANG"] = "zh_CN.UTF-8"
			environment["LC_ALL"] = "zh_CN.UTF-8"
		}
		environment["WINEDLLOVERRIDES"] = Self.dllOverrides
		try await preparePrefixIfNeeded(
			at: prefixDirectory,
			gameDirectory: gameExecutable.deletingLastPathComponent(),
			logsDirectory: logURL.deletingLastPathComponent(),
			environment: environment,
			logHandle: logHandle,
			log: log,
			spawnGate: spawnGate
		)
		RuntimePerformanceLog.write(
			stage: "prefix", since: launchStarted, to: logHandle, log: log)
		if clientVariant == .bilibili {
			try await applyBilibiliFontConfiguration(
				prefixDirectory: prefixDirectory,
				environment: environment,
				logHandle: logHandle,
				spawnGate: spawnGate,
				log: log
			)
		}
		environment.removeValue(forKey: "WINEDLLOVERRIDES")
		try await applyDisplayConfiguration(
			displayConfiguration,
			prefixDirectory: prefixDirectory,
			environment: environment,
			logHandle: logHandle,
			log: log,
			spawnGate: spawnGate
		)
		RuntimePerformanceLog.write(
			stage: "display", since: launchStarted, to: logHandle, log: log)
		environment["ARKNIGHTS_CLIENT_BROWSER_SCALE_FACTOR"] = String(
			displayConfiguration.browserScaleFactor
		)
		if displayConfiguration.metalFXUpscalingEnabled {
			environment[AppConstants.Runtime.metalFXSpatialUpscalingEnvironmentKey] = "1"
		}
		if metalPerformanceHUDEnabled {
			environment["MTL_HUD_ENABLED"] = "1"
		}
		for (key, value) in gameIconEnvironment(customIconURL: gameIconURL) {
			environment[key] = value
		}
		if isNativeARMLane {
			// The SDK login view is Qt WebEngine 5.15 (Chromium 87), whose AppContainer
			// setup is unavailable in the ARM64EC Wine build. The game throws when the
			// browser process dies, so disable the sandbox on this lane only.
			environment["QTWEBENGINE_DISABLE_SANDBOX"] = "1"
			environment["QTWEBENGINE_CHROMIUM_FLAGS"] = "--no-sandbox --disable-gpu"
			environment[AppConstants.Runtime.runtimeLaneEnvironmentKey] = "arm"
			// V8 relies on x86 total store order for its compressed pointers. FEX only
			// emulates scalar TSO by default; enable the vector and memcpy variants and
			// keep the unsafe half-barrier backpatching disabled.
			environment["FEX_TSOENABLED"] = "1"
			environment["FEX_VECTORTSOENABLED"] = "1"
			environment["FEX_MEMCPYSETTSOENABLED"] = "1"
			environment["FEX_HALFBARRIERTSOENABLED"] = "0"
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
		try spawnGate.runIfAllowed(process: process) { try process.run() }
		if clientVariant == .bilibili {
			let controller = Process()
			controller.executableURL = executableURL
			controller.arguments = [
				"G:\\BLPlatform64\\\(BilibiliPlatformCompatibility.controllerName)"
			]
			controller.currentDirectoryURL = gameExecutable.deletingLastPathComponent()
			controller.environment = Self.bilibiliControllerEnvironment(from: environment)
			controller.standardOutput = logHandle
			controller.standardError = logHandle
			do {
				try spawnGate.runIfAllowed(process: controller) { try controller.run() }
			} catch is CancellationError {
				process.terminate()
				throw CancellationError()
			} catch {
				process.terminate()
				logHandle.appendLaunchLogLine(
					"Arknights Client: Bilibili window controller failed: \(error)\n", log: log)
				throw GameRuntimeError.bilibiliControllerFailed(String(describing: error))
			}
		}
		RuntimePerformanceLog.write(
			stage: "process", since: launchStarted, to: logHandle, log: log)

		let terminationTask = Task {
			for await exit in terminationStatuses { return exit }
			// The stream ended without a termination status; never report that as a clean exit.
			return WineProcessExit(status: -1, reason: .uncaughtSignal)
		}
		return WineLaunch(
			processIdentifier: process.processIdentifier,
			terminationTask: terminationTask
		)
	}

	static func windowsGamePath(for executable: URL) -> String {
		"G:\\" + executable.lastPathComponent
	}

	static func bilibiliControllerEnvironment(
		from environment: [String: String]
	) -> [String: String] {
		var controllerEnvironment = environment
		controllerEnvironment.removeValue(forKey: "DYLD_INSERT_LIBRARIES")
		controllerEnvironment.removeValue(forKey: "ARKNIGHTS_CLIENT_GAME_ICON_PATH")
		controllerEnvironment.removeValue(forKey: "ARKNIGHTS_CLIENT_LAUNCHER_PID")
		// The controller is a helper window, so it never uses the game's cursor or MetalFX path.
		controllerEnvironment[AppConstants.Runtime.hardwareCursorEnvironmentKey] = "0"
		controllerEnvironment[AppConstants.Runtime.metalFXSpatialUpscalingEnvironmentKey] = "0"
		return controllerEnvironment
	}

}

extension FileHandle {
	/// Appends one launch-log line. Logging is best effort: a failed write is recorded, never thrown.
	func appendLaunchLogLine(_ line: String, log: LauncherLog?) {
		do {
			try write(contentsOf: Data(line.utf8))
		} catch {
			log?.error("Launch log write failed: \(error)")
		}
	}
}

enum RuntimePerformanceLog {
	static func write(
		stage: String,
		since start: ContinuousClock.Instant,
		to handle: FileHandle,
		log: LauncherLog?,
		now: ContinuousClock.Instant = .now
	) {
		let components = start.duration(to: now).components
		let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
		let line = String(
			format: "Arknights Client timing: %@=%.3fs\n",
			stage,
			max(0, seconds)
		)
		handle.appendLaunchLogLine(line, log: log)
	}
}
