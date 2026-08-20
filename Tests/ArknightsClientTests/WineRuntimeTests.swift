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
func runtimeForcesDXMTForTheGameProcess() {
	#expect(
		WineRuntime.dllOverrides
			== "d3d10core,d3d11,dxgi=n,b;winemetal=b;dcomp,mscoree,mshtml="
	)
	#expect(WineRuntime.globalRegistryOverrides["d3d11"] == "native,builtin")
	#expect(WineRuntime.globalRegistryOverrides["dxgi"] == "native,builtin")
}

@Test
func runtimeExposesPreciseScrollingRegistryKeys() {
	#expect(WineRuntime.macDriverRegistryKey == "HKCU\\Software\\Wine\\Mac Driver")
	#expect(WineRuntime.preciseScrollingRegistryValue == "UsePreciseScrolling")
	#expect(WineRuntime.normalizedScrollingRegistryData == "n")
}

@Test
func runtimeMapsTheCommandKeyToControlForVuplexClipboardShortcuts() {
	#expect(WineRuntime.leftCommandIsCtrlRegistryValue == "LeftCommandIsCtrl")
	#expect(WineRuntime.rightCommandIsCtrlRegistryValue == "RightCommandIsCtrl")
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
func runtimeUsesFastSynchronizationAndErrorOnlyDiagnostics() {
	#expect(WineRuntime.synchronizationEnvironment["WINEESYNC"] == "1")
	#expect(WineRuntime.synchronizationEnvironment["WINEMSYNC"] == nil)
	#expect(WineRuntime.debugChannels == "-all,err+all")
	let configuration = RuntimeConfiguration(
		prefixRevision: 3,
		runtime: .init(sha256: "abc")
	)
	#expect(configuration.revision == "abc-prefix-3")
}

@Test
func displayConfigurationEnablesRetinaOnlyForScaledDisplays() {
	#expect(WineDisplayConfiguration(backingScaleFactor: 2).retinaEnabled)
	#expect(!WineDisplayConfiguration(backingScaleFactor: 1).retinaEnabled)
	#expect(
		!WineDisplayConfiguration(
			backingScaleFactor: 2,
			highResolutionEnabled: false
		).retinaEnabled
	)
	#expect(
		!WineDisplayConfiguration(backingScaleFactor: 2, forceDisabled: true).retinaEnabled
	)
}

@Test
func displayConfigurationReadsOnlyTheGlobalMacDriverValue() throws {
	let fileManager = FileManager.default
	let prefix = fileManager.temporaryDirectory.appending(
		path: "retina-registry-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: prefix) }
	try fileManager.createDirectory(at: prefix, withIntermediateDirectories: true)
	let registry =
		"""
		[Software\\\\Wine\\\\AppDefaults\\\\Arknights.exe\\\\Mac Driver] 1786868781
		"RetinaMode"="n"

		[Software\\\\Wine\\\\Mac Driver] 1786868782
		"RetinaMode"="y"

		"""
	try registry.write(
		to: prefix.appending(path: "user.reg"),
		atomically: true,
		encoding: .utf8
	)

	let state = WineDisplayConfiguration(backingScaleFactor: 2).registryState(in: prefix)
	#expect(state?.retinaMode == "y")
	#expect(state?.logPixels == nil)
	#expect(state?.usePreciseScrolling == nil)
}

@Test
func displayConfigurationReadsWineDPIFromTheDesktopSection() throws {
	let fileManager = FileManager.default
	let prefix = fileManager.temporaryDirectory.appending(
		path: "dpi-registry-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: prefix) }
	try fileManager.createDirectory(at: prefix, withIntermediateDirectories: true)
	let registry =
		"""
		[Control Panel\\\\Desktop] 1786869739
		"LogPixels"=dword:000000c0

		[Software\\\\Wine\\\\Mac Driver] 1786868782
		"RetinaMode"="y"

		"""
	try registry.write(
		to: prefix.appending(path: "user.reg"),
		atomically: true,
		encoding: .utf8
	)

	let configuration = WineDisplayConfiguration(backingScaleFactor: 2)
	#expect(configuration.logPixels == 96)
	#expect(configuration.browserScaleFactor == 2)
	#expect(
		configuration.registryState(in: prefix)
			== WineDisplayRegistryState(
				retinaMode: "y",
				logPixels: 192,
				usePreciseScrolling: nil
			)
	)
}

@Test
func displayConfigurationReadsPreciseScrolling() throws {
	let fileManager = FileManager.default
	let prefix = fileManager.temporaryDirectory.appending(
		path: "scrolling-registry-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: prefix) }
	try fileManager.createDirectory(at: prefix, withIntermediateDirectories: true)
	let registry =
		"""
		[Software\\\\Wine\\\\Mac Driver] 1786868782
		"UsePreciseScrolling"="n"

		"""
	try registry.write(
		to: prefix.appending(path: "user.reg"),
		atomically: true,
		encoding: .utf8
	)

	let state = WineDisplayConfiguration(backingScaleFactor: 2).registryState(in: prefix)
	#expect(state?.usePreciseScrolling == "n")
}

@Test
func graphicsDiagnosticsExposeMacDriverAndDXMTInformation() {
	let runtime = WineRuntime(
		executableURL: URL(filePath: "/runtime/bin/Arknights"),
		displayName: "Test",
		revision: "test"
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
		gameIconBridgeURL: URL(filePath: "/runtime/GameIconBridge.dylib")
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
	let root = fileManager.temporaryDirectory.appending(
		path: "dxmt-install-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: root) }
	let payload = root.appending(path: "DXMT", directoryHint: .isDirectory)
	let prefix = root.appending(path: "prefix", directoryHint: .isDirectory)

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

	try WineRuntime.installDXMT(from: payload, in: prefix)
	#expect(WineRuntime.dxmtIsCurrent(from: payload, in: prefix))

	for (architecture, windowsDirectory) in [("x64", "system32"), ("x32", "syswow64")] {
		for library in WineRuntime.dxmtLibraryNames {
			let installed =
				prefix.appending(path: "drive_c/windows/\(windowsDirectory)/\(library)")
			#expect(try Data(contentsOf: installed) == Data("\(architecture)-\(library)".utf8))
		}
	}

	try fileManager.removeItem(
		at: prefix.appending(path: "drive_c/windows/system32/d3d11.dll")
	)
	#expect(!WineRuntime.dxmtIsCurrent(from: payload, in: prefix))
}

@Test
func hasPendingMigrationReflectsSavedStateForTheCurrentRevision() throws {
	let fileManager = FileManager.default
	let root = fileManager.temporaryDirectory.appending(
		path: "pending-migration-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: root) }
	let payload = root.appending(path: "DXMT", directoryHint: .isDirectory)
	let prefix = root.appending(path: "prefix", directoryHint: .isDirectory)
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
	try WineRuntime.installDXMT(from: payload, in: prefix)
	try Data().write(to: prefix.appending(path: "system.reg"))
	let runtime = WineRuntime(
		executableURL: root.appending(path: "bin/Arknights"),
		displayName: "Test",
		revision: "test-revision"
	)

	#expect(runtime.hasPendingMigration(prefixDirectory: prefix))

	try RuntimeMigrationStore(fileManager: fileManager).save(
		RuntimeMigrationState(
			runtimeRevision: "test-revision", completed: RuntimeMigration.allCases),
		to: prefix
	)

	#expect(!runtime.hasPendingMigration(prefixDirectory: prefix))
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
