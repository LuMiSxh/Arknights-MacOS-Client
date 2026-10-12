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
		userName: "tester"
	)

	#expect(environment["HOME"] == "/isolated/prefix/home")
	#expect(environment["TMPDIR"] == "/isolated/prefix/home/tmp")
	#expect(environment["XDG_CONFIG_HOME"] == "/isolated/prefix/home/.config")
	#expect(environment["WINEPREFIX"] == "/isolated/prefix")
	#expect(environment["WINEPRELOADERAPPNAME"] == "Arknights")
	#expect(environment["CFFIXED_USER_HOME"] == "/isolated/prefix/home")
	#expect(environment["DXMT_SHADER_CACHE"] == "1")
	#expect(environment["DXMT_SHADER_CACHE_PATH"] == "/isolated/prefix/home/.cache/dxmt")
	#expect(environment["DXMT_LOG_LEVEL"] == "error")
	#expect(environment["WINEDEBUG"] == "-all,err+all")
	#expect(environment["WINEMSYNC"] == "1")
	#expect(environment["WINEESYNC"] == nil)
	#expect(environment["DYLD_FALLBACK_LIBRARY_PATH"] == "/runtime/lib")
	#expect(environment["USER"] == "tester")
	#expect(environment["LANG"] == "en_US.UTF-8")
	#expect(environment["SSH_AUTH_SOCK"] == nil)
	#expect(environment["AWS_SECRET_ACCESS_KEY"] == nil)
	#expect(environment["PATH"] == "/runtime/bin:/usr/bin:/bin")
	#expect(
		WineRuntime.windowsGamePath(for: URL(filePath: "/Support/Arknights.exe"))
			== "G:\\Arknights.exe")

	let esync = WineRuntime.isolatedEnvironment(
		prefixDirectory: prefix,
		executableDirectory: URL(filePath: "/runtime/bin", directoryHint: .isDirectory),
		baseEnvironment: ["WINEMSYNC": "host", "WINEESYNC": "host"],
		userName: "tester",
		synchronizationMode: .esync
	)
	#expect(esync["WINEMSYNC"] == nil)
	#expect(esync["WINEESYNC"] == "1")

	let controller = WineRuntime.bilibiliControllerEnvironment(from: [
		"ARKNIGHTS_RUNTIME_HARDWARE_CURSOR": "1",
		"ARKNIGHTS_RUNTIME_CEF_COMPAT": "1",
		"DYLD_INSERT_LIBRARIES": "/runtime/bridge.dylib",
	])
	#expect(controller["ARKNIGHTS_RUNTIME_HARDWARE_CURSOR"] == nil)
	#expect(controller["DYLD_INSERT_LIBRARIES"] == nil)
	#expect(controller["ARKNIGHTS_RUNTIME_CEF_COMPAT"] == "1")
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
	#expect(WineRuntime.dxmtIsCurrent(from: fixture.payload, in: fixture.prefix))
	#expect(try Data(contentsOf: stale) == Data("old-x32".utf8))

	for library in WineRuntime.dxmtLibraryNames {
		let installed = fixture.prefix.appending(path: "drive_c/windows/system32/\(library)")
		#expect(try Data(contentsOf: installed) == Data("x64-\(library)".utf8))
	}

	try fileManager.removeItem(
		at: fixture.prefix.appending(path: "drive_c/windows/system32/d3d11.dll")
	)
	#expect(!WineRuntime.dxmtIsCurrent(from: fixture.payload, in: fixture.prefix))
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
	defer { try? FileManager.default.removeItem(at: pidFile) }
	let task = Task {
		try await runtime.runAndWait(
			executable: URL(filePath: "/bin/sh"),
			arguments: ["-c", "echo $$ > '\(pidFile.path)'; exec sleep 30"],
			environment: ProcessInfo.processInfo.environment,
			output: .nullDevice
		)
	}
	let started = await waitForCondition(timeout: .seconds(5)) {
		FileManager.default.fileExists(atPath: pidFile.path)
	}
	try #require(started)
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

private struct DXMTFixture {
	let root: URL
	let payload: URL
	let prefix: URL

	init(fileManager: FileManager, architectures: [String] = ["x64"]) throws {
		root = fileManager.temporaryDirectory.appending(
			path: "dxmt-test-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		payload = root.appending(path: "DXMT", directoryHint: .isDirectory)
		prefix = root.appending(path: "prefix", directoryHint: .isDirectory)
		for architecture in architectures {
			for library in WineRuntime.dxmtLibraryNames {
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
