// SPDX-License-Identifier: MPL-2.0

import Foundation

enum LauncherStrings {
	static let artworkAccessibility = LocalizedStringResource.Launcher.launcherArtworkAccessibility
	static let cancel = LocalizedStringResource.Launcher.launcherDialogCancel
	static let documentChangelog = LocalizedStringResource.Launcher.launcherDocumentChangelog
	static let documentLicense = LocalizedStringResource.Launcher.launcherDocumentLicense
	static let documentNotices = LocalizedStringResource.Launcher.launcherDocumentNotices
	static let documentUnavailable = LocalizedStringResource.Launcher.launcherDocumentUnavailable
	static let pickerChoose = LocalizedStringResource.Launcher.launcherFilePickerChoose
	static let pickerGameIcon = LocalizedStringResource.Launcher.launcherFilePickerGameIcon
	static let pickerInstallDirectory = LocalizedStringResource.Launcher
		.launcherFilePickerInstallDirectory
	static let pickerLauncherArtwork = LocalizedStringResource.Launcher
		.launcherFilePickerLauncherArtwork
	static let pickerLauncherIcon = LocalizedStringResource.Launcher.launcherFilePickerLauncherIcon
	static let pickerLocateInstallation = LocalizedStringResource.Launcher
		.launcherFilePickerLocateInstallation
	static let pickerUseFolder = LocalizedStringResource.Launcher.launcherFilePickerUseFolder
	static let popupDone = LocalizedStringResource.Launcher.launcherPopupDone
	static let popupNotice = LocalizedStringResource.Launcher.launcherPopupNotice
	static let updateTitle = LocalizedStringResource.Launcher.launcherUpdateTitle
	static let updateChecking = LocalizedStringResource.Launcher.launcherUpdateChecking
	static let updateAvailable = LocalizedStringResource.Launcher.launcherUpdateAvailable
	static let updateInstall = LocalizedStringResource.Launcher.launcherUpdateInstall
	static let updateInstallNow = LocalizedStringResource.Launcher.launcherUpdateInstallNow
	static let updateLater = LocalizedStringResource.Launcher.launcherUpdateLater
	static let updateCancel = LocalizedStringResource.Launcher.launcherUpdateCancel
	static let updateDone = LocalizedStringResource.Launcher.launcherUpdateDone
	static let updateCheckAgain = LocalizedStringResource.Launcher.launcherUpdateCheckAgain
	static let updateTryAgain = LocalizedStringResource.Launcher.launcherUpdateTryAgain
	static let updateMoreInformation = LocalizedStringResource.Launcher
		.launcherUpdateMoreInformation
	static let updateNoUpdate = LocalizedStringResource.Launcher.launcherUpdateNoUpdate
	static let updateFailed = LocalizedStringResource.Launcher.launcherUpdateStatusFailed
	static let updateNoUpdateDetail = LocalizedStringResource.Launcher.launcherUpdateNoUpdateDetail
	static let updateDownloading = LocalizedStringResource.Launcher.launcherUpdateDownloading
	static let updateExtracting = LocalizedStringResource.Launcher.launcherUpdateExtracting
	static let updateReady = LocalizedStringResource.Launcher.launcherUpdateReady
	static let updateReadyDetail = LocalizedStringResource.Launcher.launcherUpdateReadyDetail
	static let updateInstalling = LocalizedStringResource.Launcher.launcherUpdateInstalling
	static let updateInstallingDetail = LocalizedStringResource.Launcher
		.launcherUpdateInstallingDetail
	static let updateQuitDetail = LocalizedStringResource.Launcher.launcherUpdateQuitDetail
	static let updateWaitingDetail = LocalizedStringResource.Launcher.launcherUpdateWaitingDetail
	static let updateInstalled = LocalizedStringResource.Launcher.launcherUpdateInstalled
	static let updateInstalledDetail = LocalizedStringResource.Launcher
		.launcherUpdateInstalledDetail
	static let updateRelaunchDetail = LocalizedStringResource.Launcher.launcherUpdateRelaunchDetail
	static let updateErrorDetail = LocalizedStringResource.Launcher.launcherUpdateErrorDetail
	static let updateReleaseNotesUnavailable = LocalizedStringResource.Launcher
		.launcherUpdateReleaseNotesUnavailable
	static let updateInformationOnlyDetail = LocalizedStringResource.Launcher
		.launcherUpdateInformationOnlyDetail
	static let updateRetryQuit = LocalizedStringResource.Launcher.launcherUpdateRetryQuit

	static func updateVersion(_ version: String) -> LocalizedStringResource {
		.Launcher.launcherUpdateVersion(version)
	}
	static let rosettaInstall = LocalizedStringResource.Launcher.launcherRosettaActionInstall
	static let rosettaCancel = LocalizedStringResource.Launcher.launcherDialogCancel
	static let rosettaConfirmationMessage = LocalizedStringResource
		.Launcher.launcherRosettaConfirmationMessage
	static let rosettaConfirmationTitle = LocalizedStringResource.Launcher
		.launcherRosettaConfirmationTitle

	static func serverReset(hours: Int, minutes: Int) -> LocalizedStringResource {
		.Launcher.launcherServerResetCountdown(hours, minutes)
	}
}
