// SPDX-License-Identifier: MPL-2.0

import Foundation

enum HomeStrings {
	static let settings = LocalizedStringResource.homeSettings
	static let settingsHelp = LocalizedStringResource.homeSettingsHelp
	static let launcherUpdate = LocalizedStringResource.homeLauncherUpdate
	static let launcherUpdateHelp = LocalizedStringResource.homeLauncherUpdateHelp
	static let reportProblem = LocalizedStringResource.homeReportProblem
	static let checkAgain = LocalizedStringResource.homeCheckAgain
	static let needsAttention = LocalizedStringResource.homeStatusNeedsAttention
	static let actionStop = LocalizedStringResource.homeActionStop
	static let actionStopHelp = LocalizedStringResource.homeActionStopHelp
	static let actionPause = LocalizedStringResource.homeActionPause
	static let actionPauseHelp = LocalizedStringResource.homeActionPauseHelp
	static let actionResume = LocalizedStringResource.homeActionResume
	static let actionResumeHelp = LocalizedStringResource.homeActionResumeHelp
	static let actionInstall = LocalizedStringResource.homeActionInstall
	static let actionUpdate = LocalizedStringResource.homeActionUpdate
	static let actionUpdateHelp = LocalizedStringResource.homeActionUpdateHelp
	static let actionPlay = LocalizedStringResource.homeActionPlay
	static let actionPlayHelp = LocalizedStringResource.homeActionPlayHelp
	static let switchRegionHelp = LocalizedStringResource.homeRegionSwitchHelp
	static let versionHideDetails = LocalizedStringResource.homeVersionHideDetails
	static let versionShowDetails = LocalizedStringResource.homeVersionShowDetails
	static let versionCheckNow = LocalizedStringResource.homeVersionCheckNow
	static let versionChecking = LocalizedStringResource.homeVersionChecking
	static let versionUpToDate = LocalizedStringResource.homeVersionUpToDate

	static func downloadProgress(downloaded: String, total: String) -> LocalizedStringResource {
		.homeDownloadProgress(downloaded, total)
	}

	static func downloadPercentage(_ percentage: Int) -> LocalizedStringResource {
		.homeDownloadPercentage(percentage)
	}

	static func actionInstallHelp(region: String) -> LocalizedStringResource {
		.homeActionInstallHelp(region)
	}

	static func wordmarkAccessibility(region: String) -> LocalizedStringResource {
		.homeWordmarkAccessibility(region)
	}

	static func wordmarkFallback(region: GameRegion) -> LocalizedStringResource {
		switch region {
		case .global: .homeWordmarkFallbackGlobal
		case .japan: .homeWordmarkFallbackJapan
		case .korea: .homeWordmarkFallbackKorea
		}
	}

	static func versionAvailable(_ version: String) -> LocalizedStringResource {
		.homeVersionAvailable(version)
	}
}
