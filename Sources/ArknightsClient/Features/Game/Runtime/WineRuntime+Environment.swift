// SPDX-License-Identifier: MPL-2.0

import Foundation

extension WineRuntime {
	static func isolatedEnvironmentDirectories(prefixDirectory: URL) -> [URL] {
		let home = prefixDirectory.appending(path: "home", directoryHint: .isDirectory)
		var directories = [
			home.appending(path: ".cache", directoryHint: .isDirectory),
			home.appending(path: ".cache/dxmt", directoryHint: .isDirectory),
			home.appending(path: ".config", directoryHint: .isDirectory),
			home.appending(path: ".local/share", directoryHint: .isDirectory),
			home.appending(path: ".local/state", directoryHint: .isDirectory),
			home.appending(path: "runtime", directoryHint: .isDirectory),
			home.appending(path: "tmp", directoryHint: .isDirectory),
		]
		directories += isolatedUserDirectoryNames.map {
			home.appending(path: $0, directoryHint: .isDirectory)
		}
		return directories
	}

	static var isolatedUserDirectoryConfiguration: String {
		"""
		XDG_DESKTOP_DIR="$HOME/Desktop"
		XDG_DOCUMENTS_DIR="$HOME/Documents"
		XDG_DOWNLOAD_DIR="$HOME/Downloads"
		XDG_MUSIC_DIR="$HOME/Music"
		XDG_PICTURES_DIR="$HOME/Pictures"
		XDG_VIDEOS_DIR="$HOME/Movies"
		XDG_TEMPLATES_DIR="$HOME/Templates"

		"""
	}

	static func writeIsolatedUserDirectoryConfiguration(
		prefixDirectory: URL,
		fileManager: FileManager = .default
	) throws {
		let configurationURL =
			prefixDirectory
			.appending(path: "home/.config", directoryHint: .isDirectory)
			.appending(path: "user-dirs.dirs")
		try fileManager.createDirectory(
			at: configurationURL.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		let existingConfiguration: String?
		do {
			let data = try BoundedFileReader.readRegularFile(
				at: configurationURL,
				maximumBytes: AppConstants.Game.userDirectoryConfigurationMaximumBytes
			)
			guard let decoded = String(data: data, encoding: .utf8) else {
				throw CocoaError(.fileReadCorruptFile)
			}
			existingConfiguration = decoded
		} catch let error as POSIXError where error.code == .ENOENT {
			existingConfiguration = nil
		}
		if existingConfiguration == isolatedUserDirectoryConfiguration {
			return
		}
		try isolatedUserDirectoryConfiguration.write(
			to: configurationURL,
			atomically: true,
			encoding: .utf8
		)
	}

	static func isolatedEnvironment(
		prefixDirectory: URL,
		executableDirectory: URL,
		baseEnvironment: [String: String] = ProcessInfo.processInfo.environment,
		userName: String = NSUserName(),
		synchronizationMode: WineSynchronizationMode = .msync
	) -> [String: String] {
		let home = prefixDirectory.appending(path: "home", directoryHint: .isDirectory)
		var environment: [String: String] = [:]
		for key in inheritedEnvironmentKeys { environment[key] = baseEnvironment[key] }
		environment["HOME"] = home.path
		environment["USER"] = userName
		environment["LOGNAME"] = userName
		environment["WINEPREFIX"] = prefixDirectory.path
		environment["WINEHOMEDIR"] = home.path
		// Crash-report matching (GameSessionController.recentCrashReportPath) looks for
		// "Arknights-*.ips" under DiagnosticReports, so this name must stay in sync.
		environment["WINEPRELOADERAPPNAME"] = "Arknights"
		environment["WINEDEBUG"] = Self.debugChannels
		environment["CFFIXED_USER_HOME"] = home.path
		environment["XDG_CACHE_HOME"] = home.appending(path: ".cache").path
		environment["XDG_CONFIG_HOME"] = home.appending(path: ".config").path
		environment["XDG_DATA_HOME"] = home.appending(path: ".local/share").path
		environment["XDG_STATE_HOME"] = home.appending(path: ".local/state").path
		environment["XDG_RUNTIME_DIR"] = home.appending(path: "runtime").path
		environment["TMPDIR"] = home.appending(path: "tmp").path
		environment["TMP"] = home.appending(path: "tmp").path
		environment["TEMP"] = home.appending(path: "tmp").path
		environment["GST_REGISTRY_1_0"] = home.appending(path: ".cache/gstreamer/registry.bin").path
		environment["GST_DEBUG"] = "1"
		environment["DXMT_SHADER_CACHE"] = "1"
		environment["DXMT_SHADER_CACHE_PATH"] = home.appending(path: ".cache/dxmt").path
		// Left unset, DXMT defaults to Info-level logging on every launch, not just
		// under --graphics-diagnostics (which raises this back to "info" itself).
		environment["DXMT_LOG_LEVEL"] = "error"
		for (name, value) in Self.synchronizationEnvironment(for: synchronizationMode) {
			environment[name] = value
		}
		environment["PATH"] = [
			executableDirectory.path, "/usr/bin", "/bin",
		].joined(separator: ":")
		environment["DYLD_FALLBACK_LIBRARY_PATH"] =
			executableDirectory.deletingLastPathComponent().appending(path: "lib").path
		return environment
	}

	func runtimeEnvironment(
		prefixDirectory: URL,
		graphicsDiagnostics: Bool = false,
		synchronizationMode: WineSynchronizationMode = .msync
	) -> [String: String] {
		var environment = Self.isolatedEnvironment(
			prefixDirectory: prefixDirectory,
			executableDirectory: executableURL.deletingLastPathComponent(),
			synchronizationMode: synchronizationMode
		)
		if graphicsDiagnostics {
			environment["WINEDEBUG"] = "-all,err+all,+macdrv,+display"
			environment["DXMT_LOG_LEVEL"] = "info"
			environment["DXMT_LOG_PATH"] = "none"
		}
		return environment
	}

	/// Injects the x86-64 bridge that normalizes Wine's extracted executable icon.
	/// A custom icon path replaces that default image without modifying the game executable.
	func gameIconEnvironment(customIconURL: URL?) -> [String: String] {
		guard let gameIconBridgeURL else { return [:] }
		var environment = ["DYLD_INSERT_LIBRARIES": gameIconBridgeURL.path]
		if let customIconURL {
			environment["ARKNIGHTS_CLIENT_GAME_ICON_PATH"] = customIconURL.path
		}
		return environment
	}
}
