// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

// Game Mode can't see the actual Windows game process through Wine (it only sees the
// wrapper), so the only way to activate it is Apple's own `gamepolicyctl`, which ships solely
// inside the full Xcode.app (not the standalone Command Line Tools) — most players won't have it.
package enum GamePolicyControl {
	static let executablePath = "/Applications/Xcode.app/Contents/Developer/usr/bin/gamepolicyctl"

	package static func isAvailable(fileManager: FileManager = .default) -> Bool {
		fileManager.isExecutableFile(atPath: executablePath)
	}

	private static let requests = GameModeRequests(executable: URL(filePath: executablePath))

	// Returns after the process exits so a caller can order the next request behind it.
	static func setGameMode(on: Bool, log: LauncherLog) async {
		await requests.setGameMode(on: on, log: log)
	}

	// For app termination only, where nothing can run after the caller returns.
	static func setGameModeBlocking(on: Bool, log: LauncherLog) {
		requests.setGameModeBlocking(on: on, log: log)
	}
}
