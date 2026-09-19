// SPDX-License-Identifier: MPL-2.0

enum HomeStrings {
	static let settings = "Settings"
	static let settingsHelp = "Open launcher settings"
	static let launcherUpdate = "Install Update"
	static let launcherUpdateHelp = "Install the latest launcher update"
	static let reportProblem = "Report Problem"
	static let recoveryActions = "Actions"
	static let recoveryDetails = "Show Details"
	static let retry = "Retry"
	static let openTroubleshooting = "Open on Website"
	static let repair = "Repair"
	static let repairConfirmationTitle = "Repair game files?"
	static let repairConfirmationDetail =
		"Every game file for this region will be checked. Missing or damaged files will be downloaded again and may use substantial data. Launcher settings and the Wine prefix are preserved."
	static let repairConfirmationAction = "Start Repair"
	static let checkAgain = "Check Again"
	static let needsAttention = "Needs attention"
	static let actionStop = "Stop"
	static let actionStopHelp = "Stop Arknights and its Windows runtime"
	static let actionPause = "Pause"
	static let actionPauseHelp = "Pause the download; it resumes from partial files later"
	static let actionResume = "Resume"
	static let actionResumeHelp = "Continue downloading from the partial files"
	static let actionInstall = "Install"
	static let actionUpdate = "Update"
	static let actionUpdateHelp = "Download the changed game files"
	static let actionPlay = "Play"
	static let actionPlayHelp = "Start Arknights"
	static let switchRegionHelp = "Switch between installed regions"
	static let resetHideDetails = "Hide reset details"
	static let resetShowDetails = "Show reset details"
	static let versionHideDetails = "Hide version details"
	static let versionShowDetails = "Show version details"
	static let versionCheckNow = "Check Now"
	static let versionChecking = "Checking…"
	static let versionUpToDate = "Up to date"

	static func downloadProgress(downloaded: String, total: String) -> String {
		"\(downloaded) of \(total)"
	}

	static func downloadSpeed(_ speed: String) -> String {
		"\(speed)"
	}

	static let downloadWaiting = "Waiting for network…"

	static func downloadPercentage(_ percentage: Int) -> String {
		"\(percentage)%"
	}

	static func actionInstallHelp(region: String) -> String {
		"Download and verify the official \(region) PC files"
	}

	static func wordmarkAccessibility(region: String) -> String {
		"Arknights \(region) macOS client"
	}

	static func wordmarkFallback(region: GameRegion) -> String {
		switch region {
		case .global: "ARKNIGHTS · GLOBAL"
		case .japan: "ARKNIGHTS · JAPAN"
		case .korea: "ARKNIGHTS · KOREA"
		case .taiwan: "ARKNIGHTS · TAIWAN"
		case .china: "China (Canary)"
		case .chinaBilibili: "China — Bilibili (Canary)"
		}
	}

	static func versionAvailable(_ version: String) -> String {
		"\(version) available"
	}

	static func errorCodeAccessibility(
		code: String,
		spelling: String
	) -> String {
		"Error code \(code), spelled \(spelling)"
	}
}
