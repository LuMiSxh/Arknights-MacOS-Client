// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	func checkGameUpdates() {
		guard lifecycle.activity != .maintaining(.migratingStorage) else { return }
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.gameUpdate)
				return
			}
		#endif
		refreshController.checkGameUpdates()
	}

	func checkLauncherUpdates() {
		guard lifecycle.activity != .maintaining(.migratingStorage) else { return }
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.launcherUpdate)
				return
			}
		#endif
		communication.checkLauncherUpdates()
	}

	func checkAnnouncements() {
		guard lifecycle.activity != .maintaining(.migratingStorage) else { return }
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.announcement)
				return
			}
		#endif
		communication.checkAnnouncements(isEnabled: settings.announcementsEnabled)
	}

	func launcherUpdateCheckForOnboarding() async -> LauncherUpdateCheckOutcome {
		guard await waitForStartup() else { return .failed }
		#if DEBUG
			if isOnboardingPreview { return .current }
		#endif
		return await communication.launcherUpdateCheckForOnboarding()
	}
}
