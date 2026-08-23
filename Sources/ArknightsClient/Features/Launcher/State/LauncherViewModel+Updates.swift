// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	func checkGameUpdates() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.gameUpdate)
				return
			}
		#endif
		refreshController.checkGameUpdates()
	}

	func checkLauncherUpdates() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.launcherUpdate)
				return
			}
		#endif
		communication.checkLauncherUpdates()
	}

	func checkAnnouncements() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.announcement)
				return
			}
		#endif
		communication.checkAnnouncements(isEnabled: settings.announcementsEnabled)
	}

	func launcherUpdateCheckForOnboarding() async -> LauncherUpdateCheckOutcome {
		#if DEBUG
			if isOnboardingPreview { return .current }
		#endif
		return await communication.launcherUpdateCheckForOnboarding()
	}
}
