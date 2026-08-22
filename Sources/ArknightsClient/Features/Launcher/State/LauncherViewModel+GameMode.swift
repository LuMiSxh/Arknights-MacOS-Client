// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	/// Uses the launch-time snapshot instead of mutable preferences so every exit path
	/// reverses Game Mode even if settings change outside the UI during the session.
	func disableActiveGameMode() {
		guard activeGameModeEnabled else { return }
		activeGameModeEnabled = false
		GamePolicyControl.setGameMode(on: false, log: log)
	}
}
