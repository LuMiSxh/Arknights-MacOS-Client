// SPDX-License-Identifier: MPL-2.0

enum LauncherStrings {
	static let artworkAccessibility = "Arknights artwork"
	static let cancel = "Cancel"
	static let documentChangelog = "Changelog"
	static let documentLicense = "MPL-2.0 License"
	static let documentNotices = "Third-Party Notices"
	static let documentUnavailable = "This document is unavailable in the current build."
	static let pickerChoose = "Choose"
	static let pickerGameIcon = "Choose a game icon"
	static let pickerInstallDirectory = "Choose where to install Arknights"
	static let pickerLauncherArtwork = "Choose launcher artwork"
	static let pickerLauncherIcon = "Choose an app icon"
	static let pickerLocateInstallation = "Choose the folder containing Arknights.exe"
	static let pickerUseFolder = "Use Folder"
	static let popupDone = "Done"
	static let popupNotice = "Notice"
	static let aceWarningTitle = "ACE Anti-Cheat client"
	static let aceWarningDetail =
		"This client uses ACE Anti-Cheat. Running it through Wine is unofficial and may cause compatibility issues or consequences for your account or the service. If you continue, you play at your own risk."
	static let aceWarningAction = "Play at my own risk"
	static let updateTitle = "Launcher Update"
	static let updateChecking = "Checking for updates…"
	static let updateAvailable = "An update is available."
	static let updateInstall = "Install Update"
	static let updateInstallNow = "Install Now"
	static let updateLater = "Later"
	static let updateCancel = "Cancel"
	static let updateDone = "Done"
	static let updateCheckAgain = "Check Again"
	static let updateTryAgain = "Try Again"
	static let updateMoreInformation = "More Information"
	static let updateNoUpdate = "The launcher is up to date."
	static let updateFailed = "Couldn’t check for updates"
	static let updateNoUpdateDetail = "No newer version was found."
	static let updateDownloading = "Downloading update…"
	static let updateExtracting = "Preparing update…"
	static let updateReady = "Update is ready."
	static let updateReadyDetail = "The update can be installed now."
	static let updateInstalling = "Finishing update…"
	static let updateInstallingDetail =
		"The launcher will close and reopen automatically to finish the update."
	static let updateQuitDetail =
		"Close the game to finish the launcher update. Installation continues automatically afterward."
	static let updateWaitingDetail = "The launcher is waiting for its current activity to finish."
	static let updateInstalled = "Update installed"
	static let updateInstalledDetail = "The update was installed."
	static let updateRelaunchDetail = "The launcher was restarted."
	static let updateErrorDetail = "The update could not be completed."
	static let updateReleaseNotesUnavailable = "Release notes are unavailable."
	static let updateInformationOnlyDetail =
		"This version is informational only and cannot be installed by the launcher."
	static let updateRetryQuit = "Try Quitting Again"

	static func updateVersion(_ version: String) -> String {
		"Version \(version)"
	}
	static let rosettaInstall = "Install Rosetta 2"
	static let rosettaCancel = "Cancel"
	static let rosettaConfirmationMessage =
		"Rosetta 2 is Apple system software that lets this Apple silicon Mac run the bundled Intel-based Wine runtime. Continuing runs Apple’s software update tool and accepts Apple’s Rosetta license."
	static let rosettaConfirmationTitle = "Install Rosetta 2?"

	static func serverReset(hours: Int, minutes: Int) -> String {
		let minuteText = minutes < 10 ? "0\(minutes)" : "\(minutes)"
		return "Reset in \(hours)h \(minuteText)m"
	}
}
