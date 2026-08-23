// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	func installOrUpdate() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.downloading)
				return
			}
		#endif
		installation.installOrUpdate()
	}

	func repairGame() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.downloading)
				return
			}
		#endif
		installation.repairGame()
	}

	func cancelDownload() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.paused)
				return
			}
		#endif
		installation.cancelDownload()
	}
}
