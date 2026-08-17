// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Drives macOS Game Mode around a Wine-run session. Game Mode can't see the actual
/// Windows game process through Wine (it only sees the wrapper), so the only way to
/// activate it is Apple's own `gamepolicyctl`, which ships solely inside the full
/// Xcode.app (not the standalone Command Line Tools) — most players won't have it.
enum GamePolicyControl {
	static let executablePath = "/Applications/Xcode.app/Contents/Developer/usr/bin/gamepolicyctl"

	static func isAvailable(fileManager: FileManager = .default) -> Bool {
		fileManager.isExecutableFile(atPath: executablePath)
	}

	/// Best-effort: `gamepolicyctl` is a fast, non-interactive system policy toggle, and
	/// there's nothing useful to do if it fails, so failures are silently ignored.
	static func setGameMode(on: Bool) {
		guard isAvailable() else { return }
		let process = Process()
		process.executableURL = URL(filePath: executablePath)
		process.arguments = ["game-mode", "set", on ? "on" : "auto"]
		process.standardOutput = FileHandle.nullDevice
		process.standardError = FileHandle.nullDevice
		try? process.run()
	}
}
