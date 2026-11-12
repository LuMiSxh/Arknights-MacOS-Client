// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import CoreGraphics
import Foundation
import Testing

@testable import ArknightsGameInstallation
@testable import ArknightsGameRuntime
@testable import ArknightsInfrastructure

@Test
func runtimeEnvironmentIsConfinedToThePrefixAndDropsUnrelatedHostValues() {
	let prefix = URL(filePath: "/isolated/prefix", directoryHint: .isDirectory)
	let environment = WineRuntime.isolatedEnvironment(
		prefixDirectory: prefix,
		executableDirectory: URL(filePath: "/runtime/bin", directoryHint: .isDirectory),
		baseEnvironment: [
			"LANG": "en_US.UTF-8",
			"SSH_AUTH_SOCK": "/host/private/agent.sock",
			"AWS_SECRET_ACCESS_KEY": "secret",
		],
		userName: "tester",
		frameRateLimit: GameLaunchOptions.default.frameRateLimit
	)

	#expect(environment["HOME"] == "/isolated/prefix/home")
	#expect(environment["TMPDIR"] == "/isolated/prefix/home/tmp")
	#expect(environment["CFFIXED_USER_HOME"] == "/isolated/prefix/home")
	#expect(environment["WINEPREFIX"] == "/isolated/prefix")
	#expect(environment["DXMT_SHADER_CACHE_PATH"] == "/isolated/prefix/home/.cache/dxmt")
	#expect(environment["WINEMSYNC"] == "1")
	#expect(environment["WINEESYNC"] == nil)
	#expect(environment["DYLD_FALLBACK_LIBRARY_PATH"] == "/runtime/lib")
	#expect(environment["USER"] == "tester")
	#expect(environment["LANG"] == "en_US.UTF-8")
	#expect(environment["SSH_AUTH_SOCK"] == nil)
	#expect(environment["AWS_SECRET_ACCESS_KEY"] == nil)
	#expect(environment["PATH"] == "/runtime/bin:/usr/bin:/bin")

	let esync = WineRuntime.isolatedEnvironment(
		prefixDirectory: prefix,
		executableDirectory: URL(filePath: "/runtime/bin", directoryHint: .isDirectory),
		baseEnvironment: ["WINEMSYNC": "host", "WINEESYNC": "host"],
		userName: "tester",
		frameRateLimit: GameLaunchOptions.default.frameRateLimit,
		synchronizationMode: .esync
	)
	#expect(esync["WINEMSYNC"] == nil)
	#expect(esync["WINEESYNC"] == "1")

	let controller = WineRuntime.bilibiliControllerEnvironment(from: [
		"LMISXH_AKMOCL_CURSOR": "1",
		"LMISXH_AKMOCL_CEF": "1",
		"DXMT_METALFX_SPATIAL_SWAPCHAIN": "1",
		"DYLD_INSERT_LIBRARIES": "/runtime/bridge.dylib",
	])
	#expect(controller["LMISXH_AKMOCL_CURSOR"] == "0")
	#expect(controller["DXMT_METALFX_SPATIAL_SWAPCHAIN"] == "0")
	#expect(controller["DYLD_INSERT_LIBRARIES"] == nil)
	#expect(controller["LMISXH_AKMOCL_CEF"] == "1")
}

@Test(arguments: GameFrameRateLimit.allCases)
func frameRateLimitPassesThePickedCapToDXMT(limit: GameFrameRateLimit) {
	let environment = WineRuntime.isolatedEnvironment(
		prefixDirectory: URL(filePath: "/isolated/prefix", directoryHint: .isDirectory),
		executableDirectory: URL(filePath: "/runtime/bin", directoryHint: .isDirectory),
		baseEnvironment: [:],
		userName: "tester",
		frameRateLimit: limit
	)
	#expect(
		environment["DXMT_CONFIG"] == "d3d11.preferredMaxFrameRate=\(limit.framesPerSecond)")
}

@Test(arguments: [false, true])
func debugLoggingSelectsTheWineChannelSet(debugLogging: Bool) {
	let environment = WineRuntime.isolatedEnvironment(
		prefixDirectory: URL(filePath: "/isolated/prefix", directoryHint: .isDirectory),
		executableDirectory: URL(filePath: "/runtime/bin", directoryHint: .isDirectory),
		baseEnvironment: [:],
		userName: "tester",
		frameRateLimit: .fps120,
		debugLogging: debugLogging
	)
	let expected = debugLogging ? WineRuntime.verboseDebugChannels : WineRuntime.debugChannels
	#expect(environment["WINEDEBUG"] == expected)
}

@Test
func runtimeInstallsOnlyTheX64DXMTPayloadIntoThePrefix() throws {
	let fileManager = FileManager.default
	let fixture = try DXMTFixture(fileManager: fileManager)
	defer { fixture.remove(fileManager: fileManager) }
	let stale = fixture.prefix.appending(path: "drive_c/windows/syswow64/d3d11.dll")
	try fileManager.createDirectory(
		at: stale.deletingLastPathComponent(), withIntermediateDirectories: true)
	try Data("old-x32".utf8).write(to: stale)

	try WineRuntime.installDXMT(from: fixture.payload, in: fixture.prefix)
	#expect(try WineRuntime.dxmtIsCurrent(from: fixture.payload, in: fixture.prefix))
	#expect(try Data(contentsOf: stale) == Data("old-x32".utf8))

	for library in WineRuntime.dxmtLibraryNames {
		let installed = fixture.prefix.appending(path: "drive_c/windows/system32/\(library)")
		#expect(try Data(contentsOf: installed) == Data("x64-\(library)".utf8))
	}

	try fileManager.removeItem(
		at: fixture.prefix.appending(path: "drive_c/windows/system32/d3d11.dll")
	)
	#expect(!(try WineRuntime.dxmtIsCurrent(from: fixture.payload, in: fixture.prefix)))
}

@Test
func runtimeInstallsTheARMDXMTPayloadFromTheInterface() throws {
	let fileManager = FileManager.default
	let libraries = ["d3d10core.dll", "d3d11.dll", "dxgi.dll"]
	let destinations = [
		WineRuntime.DXMTDestination(architecture: "x64", windowsDirectory: "system32")
	]
	let fixture = try DXMTFixture(fileManager: fileManager, libraries: libraries)
	defer { fixture.remove(fileManager: fileManager) }

	try WineRuntime.installDXMT(
		from: fixture.payload,
		in: fixture.prefix,
		destinations: destinations,
		libraries: libraries
	)
	#expect(
		try WineRuntime.dxmtIsCurrent(
			from: fixture.payload,
			in: fixture.prefix,
			destinations: destinations,
			libraries: libraries
		)
	)
	let installed = fixture.prefix.appending(
		path: "drive_c/windows/system32",
		directoryHint: .isDirectory
	)
	#expect(!fileManager.fileExists(atPath: installed.appending(path: "winemetal.dll").path))
}

@Test
func injectedBridgesShareTheDynamicLoaderPath() {
	let runtime = WineRuntime(
		executableURL: URL(filePath: "/runtime/bin/Arknights"),
		displayName: "Test",
		revision: "test",
		gameIconBridgeURL: URL(filePath: "/runtime/GameIconBridge.dylib"),
		compatibilityManager: GameCompatibilityManager()
	)
	let environment = runtime.gameIconEnvironment(customIconURL: nil)
	#expect(
		environment["DYLD_INSERT_LIBRARIES"]
			== "/runtime/GameIconBridge.dylib")
}

@Test
func runtimeProcessWaitTerminatesAndResumesWhenCancelled() async throws {
	let runtime = WineRuntime(
		executableURL: URL(filePath: "/runtime/bin/Arknights"),
		displayName: "Test",
		revision: "test",
		compatibilityManager: GameCompatibilityManager()
	)
	let pidFile = FileManager.default.temporaryDirectory.appending(
		path: "runtime-wait-\(UUID().uuidString).pid")
	// best effort: the test owns this temporary file.
	defer { try? FileManager.default.removeItem(at: pidFile) }
	let task = Task {
		try await runtime.runAndWait(
			executable: URL(filePath: "/bin/sh"),
			arguments: ["-c", "echo $$ > '\(pidFile.path)'; exec sleep 30"],
			environment: ProcessInfo.processInfo.environment,
			output: .nullDevice
		)
	}
	await waitForFile(at: pidFile)
	task.cancel()

	await #expect(throws: CancellationError.self) {
		try await task.value
	}
}

@Test
func gameWindowReadinessRequiresALargeVisibleWindowAndTimesOutWithoutOne() async {
	func window(_ side: Int) -> [String: Any] {
		[
			kCGWindowOwnerPID as String: 42, kCGWindowLayer as String: 0,
			kCGWindowIsOnscreen as String: true, kCGWindowAlpha as String: 1,
			kCGWindowBounds as String: ["Width": side, "Height": side],
		]
	}
	#expect(!WineWindowReadiness.isVisible(processIdentifier: 42, windows: [window(1)]))
	#expect(
		WineWindowReadiness.isVisible(processIdentifier: 42, windows: [window(1), window(900)]))

	await #expect(throws: GameRuntimeError.self) {
		try await WineWindowReadiness.wait(
			processIdentifier: Int32.max, timeout: .milliseconds(2), pollInterval: .milliseconds(1))
	}
}

@Test
func runtimeProvidesOnlyPrivateUnixUserDirectoriesAndRejectsInvalidConfiguration() throws {
	let fileManager = FileManager.default
	let root = fileManager.temporaryDirectory.appending(
		path: "wine-environment-test-\(UUID().uuidString)", directoryHint: .isDirectory)
	// best effort: the test owns this temporary directory.
	defer { try? fileManager.removeItem(at: root) }
	for directory in WineRuntime.isolatedEnvironmentDirectories(prefixDirectory: root) {
		try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
	}
	try WineRuntime.writeIsolatedUserDirectoryConfiguration(prefixDirectory: root)
	let configurationURL = root.appending(path: "home/.config/user-dirs.dirs")
	#expect(
		try String(contentsOf: configurationURL, encoding: .utf8)
			== WineRuntime.isolatedUserDirectoryConfiguration)
	for name in WineRuntime.isolatedUserDirectoryNames {
		#expect(fileManager.fileExists(atPath: root.appending(path: "home/\(name)").path))
	}

	try Data(repeating: 0x41, count: AppConstants.Game.userDirectoryConfigurationMaximumBytes + 1)
		.write(to: configurationURL)
	#expect(throws: BoundedFileReadError.self) {
		try WineRuntime.writeIsolatedUserDirectoryConfiguration(prefixDirectory: root)
	}
	try Data([0xC3, 0x28]).write(to: configurationURL)
	#expect(throws: Error.self) {
		try WineRuntime.writeIsolatedUserDirectoryConfiguration(prefixDirectory: root)
	}
}

@Suite
struct WineRuntimeDiscoveryTests {
	@Test
	func pathBasedDiscoveryResolvesTheRuntime() throws {
		let fileManager = FileManager.default
		let root = fileManager.temporaryDirectory.appending(
			path: "wine-path-discovery-\(UUID().uuidString)", directoryHint: .isDirectory)
		defer {
			// best effort: the fixture lives under the system temporary directory.
			try? fileManager.removeItem(at: root)
		}
		let bin = root.appending(path: "bin", directoryHint: .isDirectory)
		try fileManager.createDirectory(at: bin, withIntermediateDirectories: true)
		let executable = bin.appending(path: "Arknights")
		try Data("#!/bin/sh\n".utf8).write(to: executable)
		try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
		let configurationURL = root.appending(path: "RUNTIME.json")
		try Data(
			#"""
			{
			  "prefixRevision": 2,
			  "architecture": "arm",
			  "runtime": {"name": "Test Runtime", "sha256": "abc"},
			  "interface": {
			    "archive": {"wineDirectory": "Wine", "dxmtDirectory": "DXMT"},
			    "executables": ["bin/wine64"],
			    "features": {
			      "hardwareCursor": true,
			      "metalFXSpatialUpscaling": false,
			      "nativeFullscreenSpace": false
			    },
			    "requiredFiles": ["lib/wine/aarch64-unix/winemac.so"],
			    "macDriver": "lib/wine/aarch64-unix/winemac.so",
			    "launcher": {"path": "bin/Arknights", "target": "wine64"},
			    "dxmt": {
			      "payloadDirectory": "Payload",
			      "destinations": {"x64": "system32"},
			      "libraries": ["d3d11.dll"]
			    }
			  }
			}
			"""#.utf8
		).write(to: configurationURL)

		let runtime = try WineRuntime.discover(
			runtimeRoot: root,
			configurationURL: configurationURL,
			compatibilityManager: GameCompatibilityManager()
		)

		#expect(runtime.executableURL == executable)
		#expect(runtime.lane == .arm)
		#expect(runtime.displayName == "Test Runtime")
		#expect(runtime.dxmtPayloadDirectory == "Payload")
		#expect(runtime.dxmtPayloadLibraries == ["d3d11.dll"])
		#expect(
			runtime.features
				== RuntimeFeatures(
					hardwareCursor: true, metalFXSpatialUpscaling: false,
					nativeFullscreenSpace: false))
	}
}

private struct DXMTFixture {
	let root: URL
	let payload: URL
	let prefix: URL

	init(
		fileManager: FileManager,
		architectures: [String] = ["x64"],
		libraries: [String] = WineRuntime.dxmtLibraryNames
	) throws {
		root = fileManager.temporaryDirectory.appending(
			path: "dxmt-test-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		payload = root.appending(path: "DXMT", directoryHint: .isDirectory)
		prefix = root.appending(path: "prefix", directoryHint: .isDirectory)
		for architecture in architectures {
			for library in libraries {
				let source = payload.appending(path: architecture).appending(path: library)
				try fileManager.createDirectory(
					at: source.deletingLastPathComponent(),
					withIntermediateDirectories: true
				)
				try Data("\(architecture)-\(library)".utf8).write(to: source)
			}
		}
	}

	func remove(fileManager: FileManager) {
		try? fileManager.removeItem(at: root)
	}
}
