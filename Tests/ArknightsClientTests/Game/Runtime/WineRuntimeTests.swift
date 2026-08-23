// SPDX-License-Identifier: MPL-2.0

import CoreGraphics
import Foundation
import Testing

@testable import ArknightsClient

@Test
func gameExecutableUsesTheIsolatedWindowsDrive() {
	let executable = URL(filePath: "/Applications/Support/Arknights-Global/Arknights.exe")

	#expect(WineRuntime.windowsGamePath(for: executable) == "G:\\Arknights.exe")
}

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
}

@Test
func runtimeProvidesOnlyPrivateUnixUserDirectoriesToWineboot() throws {
	let fileManager = FileManager.default
	let root = fileManager.temporaryDirectory.appending(
		path: "wine-environment-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: root) }

	for directory in WineRuntime.isolatedEnvironmentDirectories(prefixDirectory: root) {
		try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
	}
	try WineRuntime.writeIsolatedUserDirectoryConfiguration(prefixDirectory: root)

	let configurationURL = root.appending(path: "home/.config/user-dirs.dirs")
	let originalFileNumber =
		try FileManager.default.attributesOfItem(atPath: configurationURL.path)[
			.systemFileNumber
		] as? NSNumber
	try WineRuntime.writeIsolatedUserDirectoryConfiguration(prefixDirectory: root)
	let preservedFileNumber =
		try FileManager.default.attributesOfItem(atPath: configurationURL.path)[
			.systemFileNumber
		] as? NSNumber
	let configuration = try String(contentsOf: configurationURL, encoding: .utf8)
	#expect(preservedFileNumber == originalFileNumber)
	#expect(configuration == WineRuntime.isolatedUserDirectoryConfiguration)
	#expect(configuration.contains("XDG_DOCUMENTS_DIR=\"$HOME/Documents\""))
	#expect(configuration.contains("XDG_DOWNLOAD_DIR=\"$HOME/Downloads\""))
	for name in WineRuntime.isolatedUserDirectoryNames {
		#expect(fileManager.fileExists(atPath: root.appending(path: "home/\(name)").path))
	}
}

@Test
func runtimeEnablesOnlyTheSelectedSynchronizationMode() {
	let environment = WineRuntime.isolatedEnvironment(
		prefixDirectory: URL(filePath: "/prefix", directoryHint: .isDirectory),
		executableDirectory: URL(filePath: "/runtime/bin", directoryHint: .isDirectory),
		baseEnvironment: ["WINEMSYNC": "host", "WINEESYNC": "host"],
		userName: "tester",
		synchronizationMode: .esync
	)

	#expect(environment["WINEMSYNC"] == nil)
	#expect(environment["WINEESYNC"] == "1")
}

@Test
func graphicsDiagnosticsExposeMacDriverAndDXMTInformation() {
	let runtime = WineRuntime(
		executableURL: URL(filePath: "/runtime/bin/Arknights"),
		displayName: "Test",
		revision: "test",
		compatibilityManager: GameCompatibilityManager()
	)
	let environment = runtime.runtimeEnvironment(
		prefixDirectory: URL(filePath: "/prefix", directoryHint: .isDirectory),
		graphicsDiagnostics: true
	)

	#expect(environment["WINEDEBUG"]?.contains("+macdrv") == true)
	#expect(environment["DXMT_LOG_LEVEL"] == "info")
	#expect(environment["DXMT_LOG_PATH"] == "none")
}

@Test
func gameIconEnvironmentInjectsBridgeAndOptionalCustomIcon() {
	let runtime = WineRuntime(
		executableURL: URL(filePath: "/runtime/bin/Arknights"),
		displayName: "Test",
		revision: "test",
		gameIconBridgeURL: URL(filePath: "/runtime/GameIconBridge.dylib"),
		compatibilityManager: GameCompatibilityManager()
	)

	#expect(
		runtime.gameIconEnvironment(customIconURL: nil)
			== ["DYLD_INSERT_LIBRARIES": "/runtime/GameIconBridge.dylib"]
	)
	#expect(
		runtime.gameIconEnvironment(customIconURL: URL(filePath: "/icons/game.png"))
			== [
				"DYLD_INSERT_LIBRARIES": "/runtime/GameIconBridge.dylib",
				"ARKNIGHTS_CLIENT_GAME_ICON_PATH": "/icons/game.png",
			]
	)
}

@Test
func runtimeInstallsBothDXMTPayloadsIntoThePrefix() throws {
	let fileManager = FileManager.default
	let fixture = try DXMTFixture(fileManager: fileManager)
	defer { fixture.remove(fileManager: fileManager) }

	try WineRuntime.installDXMT(from: fixture.payload, in: fixture.prefix)
	#expect(WineRuntime.dxmtIsCurrent(from: fixture.payload, in: fixture.prefix))

	for (architecture, windowsDirectory) in [("x64", "system32"), ("x32", "syswow64")] {
		for library in WineRuntime.dxmtLibraryNames {
			let installed =
				fixture.prefix.appending(
					path: "drive_c/windows/\(windowsDirectory)/\(library)"
				)
			#expect(try Data(contentsOf: installed) == Data("\(architecture)-\(library)".utf8))
		}
	}

	try fileManager.removeItem(
		at: fixture.prefix.appending(path: "drive_c/windows/system32/d3d11.dll")
	)
	#expect(!WineRuntime.dxmtIsCurrent(from: fixture.payload, in: fixture.prefix))
}

@Test
func hasPendingMigrationReflectsSavedStateForTheCurrentRevision() throws {
	let fileManager = FileManager.default
	let fixture = try DXMTFixture(fileManager: fileManager)
	defer { fixture.remove(fileManager: fileManager) }
	try WineRuntime.installDXMT(from: fixture.payload, in: fixture.prefix)
	try Data().write(to: fixture.prefix.appending(path: "system.reg"))
	let runtime = WineRuntime(
		executableURL: fixture.root.appending(path: "bin/Arknights"),
		displayName: "Test",
		revision: "test-revision",
		compatibilityManager: GameCompatibilityManager()
	)

	#expect(runtime.hasPendingMigration(prefixDirectory: fixture.prefix))

	try RuntimeMigrationStore(fileManager: fileManager).save(
		RuntimeMigrationState(
			runtimeRevision: "test-revision", completed: RuntimeMigration.allCases),
		to: fixture.prefix
	)

	#expect(!runtime.hasPendingMigration(prefixDirectory: fixture.prefix))
}

@Test
func gameWindowReadinessRequiresALargeVisibleWindowForTheRuntimeProcess() {
	let processIdentifier: Int32 = 42
	let helperWindow: [String: Any] = [
		kCGWindowOwnerPID as String: processIdentifier,
		kCGWindowLayer as String: 0,
		kCGWindowIsOnscreen as String: true,
		kCGWindowAlpha as String: 1,
		kCGWindowBounds as String: ["Width": 1, "Height": 1],
	]
	let gameWindow: [String: Any] = [
		kCGWindowOwnerPID as String: processIdentifier,
		kCGWindowLayer as String: 0,
		kCGWindowIsOnscreen as String: true,
		kCGWindowAlpha as String: 1,
		kCGWindowBounds as String: ["Width": 1280, "Height": 720],
	]

	#expect(
		!WineWindowReadiness.isVisible(
			processIdentifier: processIdentifier,
			windows: [helperWindow]
		))
	#expect(
		WineWindowReadiness.isVisible(
			processIdentifier: processIdentifier,
			windows: [helperWindow, gameWindow]
		))
}

@Test
func gameWindowReadinessTimesOutWhenTheRuntimeNeverCreatesAWindow() async {
	await #expect(throws: LauncherError.self) {
		try await WineWindowReadiness.wait(
			processIdentifier: Int32.max,
			timeout: .milliseconds(2),
			pollInterval: .milliseconds(1)
		)
	}
}

@Test
func runtimeProcessWaitTerminatesAndResumesWhenCancelled() async throws {
	let runtime = WineRuntime(
		executableURL: URL(filePath: "/runtime/bin/Arknights"),
		displayName: "Test",
		revision: "test",
		compatibilityManager: GameCompatibilityManager()
	)
	let task = Task {
		try await runtime.runAndWait(
			executable: URL(filePath: "/bin/sh"),
			arguments: ["-c", "exec sleep 30"],
			environment: ProcessInfo.processInfo.environment,
			output: .nullDevice
		)
	}
	try await Task.sleep(for: .milliseconds(50))
	task.cancel()

	await #expect(throws: CancellationError.self) {
		try await task.value
	}
}

private struct DXMTFixture {
	let root: URL
	let payload: URL
	let prefix: URL

	init(fileManager: FileManager) throws {
		root = fileManager.temporaryDirectory.appending(
			path: "dxmt-test-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		payload = root.appending(path: "DXMT", directoryHint: .isDirectory)
		prefix = root.appending(path: "prefix", directoryHint: .isDirectory)
		for architecture in ["x64", "x32"] {
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
