// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	func chooseInstallDirectory() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		installation.chooseInstallDirectory()
	}

	func locateExistingInstallation() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		installation.locateExistingInstallation()
	}

	func resetAllLauncherSettings() {
		guard settings.resetToDefaults(canModifyLaunchOptions: !gameSession.isGameActive) else {
			return
		}
		Task { [log] in await log.info("Launcher settings reset to default") }
	}

	func uninstallGame() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		installation.uninstallGame()
	}
}
