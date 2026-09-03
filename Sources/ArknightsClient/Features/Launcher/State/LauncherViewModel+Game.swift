// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	func launch() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.launching)
				return
			}
		#endif
		gameSession.launch()
	}

	func stopGame() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.ready)
				return
			}
		#endif
		gameSession.stopGame()
	}

	func stopGameForApplicationTermination() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		gameSession.stopGameForApplicationTermination()
	}
}
