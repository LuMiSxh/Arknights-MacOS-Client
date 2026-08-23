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
	static let popupLater = LocalizedStringResource.Launcher.launcherPopupLater
	static let popupNotice = LocalizedStringResource.Launcher.launcherPopupNotice
	static let popupReleaseFallback = LocalizedStringResource.Launcher.launcherPopupReleaseFallback
	static let popupViewRelease = LocalizedStringResource.Launcher.launcherPopupViewRelease
	static let rosettaInstall = LocalizedStringResource.Launcher.launcherRosettaActionInstall
	static let rosettaCancel = LocalizedStringResource.Launcher.launcherDialogCancel
	static let rosettaConfirmationMessage = LocalizedStringResource
		.Launcher.launcherRosettaConfirmationMessage
	static let rosettaConfirmationTitle = LocalizedStringResource.Launcher
		.launcherRosettaConfirmationTitle

	static func popupUpdateTitle(_ version: String) -> LocalizedStringResource {
		.Launcher.launcherPopupUpdateTitle(version)
	}

	static func serverReset(hours: Int, minutes: Int) -> LocalizedStringResource {
		.Launcher.launcherServerResetCountdown(hours, minutes)
	}
}
