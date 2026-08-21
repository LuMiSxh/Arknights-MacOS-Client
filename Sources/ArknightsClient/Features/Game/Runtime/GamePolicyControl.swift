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

	/// Requests the policy change without blocking launch and records start or exit failures.
	static func setGameMode(on: Bool, log: LauncherLog) {
		guard isAvailable() else {
			Task {
				await log.debug("Game Mode request skipped because gamepolicyctl is unavailable")
			}
			return
		}
		let process = Process()
		process.executableURL = URL(filePath: executablePath)
		process.arguments = ["game-mode", "set", on ? "on" : "auto"]
		process.standardOutput = FileHandle.nullDevice
		process.standardError = FileHandle.nullDevice
		process.terminationHandler = { process in
			guard process.terminationStatus != 0 else { return }
			Task {
				await log.error(
					"gamepolicyctl exited with status \(process.terminationStatus) while setting Game Mode \(on ? "on" : "auto")"
				)
			}
		}
		do {
			try process.run()
		} catch {
			Task {
				await log.error(
					"Failed to start gamepolicyctl for Game Mode \(on ? "on" : "auto"): \(error.localizedDescription)"
				)
			}
		}
	}
}
