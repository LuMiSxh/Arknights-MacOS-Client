// SPDX-License-Identifier: MPL-2.0

//
// GeneratedStringSymbols_Launcher.swift
// Auto-Generated symbols for localized strings defined in “Launcher.xcstrings”.
//

import Foundation

#if SWIFT_PACKAGE
	private nonisolated let resourceBundle = AppResourceBundle.bundle
	@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
	private nonisolated let resourceBundleDescription = LocalizedStringResource.BundleDescription
		.atURL(resourceBundle.bundleURL)
#else

	private class ResourceBundleClass {}
	@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
	private nonisolated let resourceBundleDescription = LocalizedStringResource.BundleDescription
		.forClass(ResourceBundleClass.self)
#endif

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
nonisolated extension LocalizedStringResource {
	/// Namespace for strings in file “Launcher.xcstrings”.
	enum Launcher {
		/**
		 Accessibility label for the launcher background artwork

		 Localized string for key “launcher.artwork.accessibility” in table “Launcher.xcstrings”.
		 */
		static var launcherArtworkAccessibility: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.artwork.accessibility", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Cancel action

		 Localized string for key “launcher.dialog.cancel” in table “Launcher.xcstrings”.
		 */
		static var launcherDialogCancel: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.dialog.cancel", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Title of the bundled changelog

		 Localized string for key “launcher.document.changelog” in table “Launcher.xcstrings”.
		 */
		static var launcherDocumentChangelog: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.document.changelog", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Title of the bundled project license

		 Localized string for key “launcher.document.license” in table “Launcher.xcstrings”.
		 */
		static var launcherDocumentLicense: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.document.license", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Title of bundled third-party notices

		 Localized string for key “launcher.document.notices” in table “Launcher.xcstrings”.
		 */
		static var launcherDocumentNotices: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.document.notices", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Fallback when a bundled document cannot be loaded

		 Localized string for key “launcher.document.unavailable” in table “Launcher.xcstrings”.
		 */
		static var launcherDocumentUnavailable: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.document.unavailable", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Installer cannot create its temporary file; path follows

		 Localized string for key “launcher.error.cannotCreateFile” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorCannotCreateFile(_ arg1: String) -> LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.cannotCreateFile", defaultValue: "\(arg1)", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Selected image cannot become app icon

		 Localized string for key “launcher.error.cannotEncodeAppIcon” in table “Launcher.xcstrings”.
		 */
		static var launcherErrorCannotEncodeAppIcon: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.cannotEncodeAppIcon", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 macOS refused app icon update

		 Localized string for key “launcher.error.cannotSetAppIcon” in table “Launcher.xcstrings”.
		 */
		static var launcherErrorCannotSetAppIcon: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.cannotSetAppIcon", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 CRC check failed; file, actual checksum, expected checksum follow

		 Localized string for key “launcher.error.checksumMismatch” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorChecksumMismatch(_ arg1: String, _ arg2: String, _ arg3: String)
			-> LocalizedStringResource
		{
			LocalizedStringResource(
				"launcher.error.checksumMismatch", defaultValue: "\(arg1)\(arg2)\(arg3)",
				table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Two game manifest paths conflict; both paths follow

		 Localized string for key “launcher.error.conflictingManifestPaths” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorConflictingManifestPaths(_ arg1: String, _ arg2: String)
			-> LocalizedStringResource
		{
			LocalizedStringResource(
				"launcher.error.conflictingManifestPaths", defaultValue: "\(arg1)\(arg2)",
				table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Download returned an HTTP status; path then status follow

		 Localized string for key “launcher.error.downloadResponse” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorDownloadResponse(_ arg1: String, _ arg2: String)
			-> LocalizedStringResource
		{
			LocalizedStringResource(
				"launcher.error.downloadResponse", defaultValue: "\(arg1)\(arg2)",
				table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Downloaded file has wrong byte size; path, actual and expected byte counts follow

		 Localized string for key “launcher.error.downloadedSizeMismatch” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorDownloadedSizeMismatch(
			_ arg1: String, _ arg2: String, _ arg3: String
		) -> LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.downloadedSizeMismatch", defaultValue: "\(arg1)\(arg2)\(arg3)",
				table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Game manifest includes a duplicate path

		 Localized string for key “launcher.error.duplicateManifestPath” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorDuplicateManifestPath(_ arg1: String) -> LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.duplicateManifestPath", defaultValue: "\(arg1)", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Arknights executable was not found; path follows

		 Localized string for key “launcher.error.gameNotInstalled” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorGameNotInstalled(_ arg1: String) -> LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.gameNotInstalled", defaultValue: "\(arg1)", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Required and available disk space follow

		 Localized string for key “launcher.error.insufficientDiskSpace” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorInsufficientDiskSpace(_ arg1: String, _ arg2: String)
			-> LocalizedStringResource
		{
			LocalizedStringResource(
				"launcher.error.insufficientDiskSpace", defaultValue: "\(arg1)\(arg2)",
				table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Rosetta cannot start Wine

		 Localized string for key “launcher.error.intelTranslationUnavailable” in table “Launcher.xcstrings”.
		 */
		static var launcherErrorIntelTranslationUnavailable: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.intelTranslationUnavailable", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 macOS version no longer supports Wine Rosetta requirement

		 Localized string for key “launcher.error.intelTranslationUnsupported” in table “Launcher.xcstrings”.
		 */
		static var launcherErrorIntelTranslationUnsupported: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.intelTranslationUnsupported", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Selected custom image is unsupported; path follows

		 Localized string for key “launcher.error.invalidCustomImage” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorInvalidCustomImage(_ arg1: String) -> LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.invalidCustomImage", defaultValue: "\(arg1)", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Unsafe game manifest path

		 Localized string for key “launcher.error.invalidManifestPath” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorInvalidManifestPath(_ arg1: String) -> LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.invalidManifestPath", defaultValue: "\(arg1)", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Preset image is unsupported or unsafe; URL follows

		 Localized string for key “launcher.error.invalidPresetImage” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorInvalidPresetImage(_ arg1: String) -> LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.invalidPresetImage", defaultValue: "\(arg1)", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Remote asset URL was refused

		 Localized string for key “launcher.error.invalidRemoteAsset” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorInvalidRemoteAsset(_ arg1: String) -> LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.invalidRemoteAsset", defaultValue: "\(arg1)", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Yostar server sent invalid response

		 Localized string for key “launcher.error.invalidResponse” in table “Launcher.xcstrings”.
		 */
		static var launcherErrorInvalidResponse: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.invalidResponse", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Game configuration has not loaded

		 Localized string for key “launcher.error.missingConfiguration” in table “Launcher.xcstrings”.
		 */
		static var launcherErrorMissingConfiguration: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.missingConfiguration", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Remote host and size limit follow

		 Localized string for key “launcher.error.remoteContentTooLarge” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorRemoteContentTooLarge(_ arg1: String, _ arg2: String)
			-> LocalizedStringResource
		{
			LocalizedStringResource(
				"launcher.error.remoteContentTooLarge", defaultValue: "\(arg1)\(arg2)",
				table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 macOS Legacy Game Test Mode blocks Rosetta; command stays technical

		 Localized string for key “launcher.error.rosettaDisabled” in table “Launcher.xcstrings”.
		 */
		static var launcherErrorRosettaDisabled: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.rosettaDisabled", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Rosetta required; command stays technical

		 Localized string for key “launcher.error.rosettaMissing” in table “Launcher.xcstrings”.
		 */
		static var launcherErrorRosettaMissing: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.rosettaMissing", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Windows runtime setup failed; technical reason follows

		 Localized string for key “launcher.error.runtimeConfiguration” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorRuntimeConfiguration(_ arg1: String) -> LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.runtimeConfiguration", defaultValue: "\(arg1)", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Windows runtime exit status and log path follow

		 Localized string for key “launcher.error.runtimeExited” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorRuntimeExited(_ arg1: String, _ arg2: String)
			-> LocalizedStringResource
		{
			LocalizedStringResource(
				"launcher.error.runtimeExited", defaultValue: "\(arg1)\(arg2)", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Game did not show a window in time

		 Localized string for key “launcher.error.runtimeWindowTimeout” in table “Launcher.xcstrings”.
		 */
		static var launcherErrorRuntimeWindowTimeout: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.runtimeWindowTimeout", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Yostar API code and unmodified message follow

		 Localized string for key “launcher.error.server” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorServer(_ arg1: String, _ arg2: String) -> LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.server", defaultValue: "\(arg1)\(arg2)", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Installer refused symlink in destination; path follows

		 Localized string for key “launcher.error.symbolicLink” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorSymbolicLink(_ arg1: String) -> LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.symbolicLink", defaultValue: "\(arg1)", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Installer refused unsafe temporary file; path follows

		 Localized string for key “launcher.error.unsafeTemporaryFile” in table “Launcher.xcstrings”.
		 */
		static func launcherErrorUnsafeTemporaryFile(_ arg1: String) -> LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.unsafeTemporaryFile", defaultValue: "\(arg1)", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Compatible Wine runtime is missing

		 Localized string for key “launcher.error.wineRuntimeMissing” in table “Launcher.xcstrings”.
		 */
		static var launcherErrorWineRuntimeMissing: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.error.wineRuntimeMissing", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Generic file picker confirmation action

		 Localized string for key “launcher.filePicker.choose” in table “Launcher.xcstrings”.
		 */
		static var launcherFilePickerChoose: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.filePicker.choose", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Title for game icon picker

		 Localized string for key “launcher.filePicker.gameIcon” in table “Launcher.xcstrings”.
		 */
		static var launcherFilePickerGameIcon: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.filePicker.gameIcon", table: "Launcher", bundle: resourceBundleDescription
			)
		}

		/**
		 Title for install directory picker

		 Localized string for key “launcher.filePicker.installDirectory” in table “Launcher.xcstrings”.
		 */
		static var launcherFilePickerInstallDirectory: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.filePicker.installDirectory", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Title for launcher artwork picker

		 Localized string for key “launcher.filePicker.launcherArtwork” in table “Launcher.xcstrings”.
		 */
		static var launcherFilePickerLauncherArtwork: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.filePicker.launcherArtwork", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Title for launcher icon picker

		 Localized string for key “launcher.filePicker.launcherIcon” in table “Launcher.xcstrings”.
		 */
		static var launcherFilePickerLauncherIcon: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.filePicker.launcherIcon", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Title for existing game folder picker

		 Localized string for key “launcher.filePicker.locateInstallation” in table “Launcher.xcstrings”.
		 */
		static var launcherFilePickerLocateInstallation: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.filePicker.locateInstallation", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Existing game folder picker confirmation action

		 Localized string for key “launcher.filePicker.useFolder” in table “Launcher.xcstrings”.
		 */
		static var launcherFilePickerUseFolder: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.filePicker.useFolder", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Dismiss popup action

		 Localized string for key “launcher.popup.done” in table “Launcher.xcstrings”.
		 */
		static var launcherPopupDone: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.popup.done", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Defer launcher update action

		 Localized string for key “launcher.popup.later” in table “Launcher.xcstrings”.
		 */
		static var launcherPopupLater: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.popup.later", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Generic official notice title

		 Localized string for key “launcher.popup.notice” in table “Launcher.xcstrings”.
		 */
		static var launcherPopupNotice: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.popup.notice", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Fallback update popup content when release notes are blank

		 Localized string for key “launcher.popup.releaseFallback” in table “Launcher.xcstrings”.
		 */
		static var launcherPopupReleaseFallback: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.popup.releaseFallback", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Launcher update popup title; version follows

		 Localized string for key “launcher.popup.updateTitle” in table “Launcher.xcstrings”.
		 */
		static func launcherPopupUpdateTitle(_ arg1: String) -> LocalizedStringResource {
			LocalizedStringResource(
				"launcher.popup.updateTitle", defaultValue: "\(arg1)", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Open launcher release action

		 Localized string for key “launcher.popup.viewRelease” in table “Launcher.xcstrings”.
		 */
		static var launcherPopupViewRelease: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.popup.viewRelease", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Install Rosetta action

		 Localized string for key “launcher.rosetta.action.install” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaActionInstall: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.action.install", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Retry Rosetta installation action

		 Localized string for key “launcher.rosetta.action.installAgain” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaActionInstallAgain: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.action.installAgain", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Install Rosetta action with ellipsis

		 Localized string for key “launcher.rosetta.action.installEllipsis” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaActionInstallEllipsis: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.action.installEllipsis", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Explanation before starting Apple's Rosetta installer

		 Localized string for key “launcher.rosetta.confirmation.message” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaConfirmationMessage: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.confirmation.message", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Rosetta installation confirmation title

		 Localized string for key “launcher.rosetta.confirmation.title” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaConfirmationTitle: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.confirmation.title", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Intel compatibility is being checked

		 Localized string for key “launcher.rosetta.detail.availableCheck” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaDetailAvailableCheck: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.detail.availableCheck", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Legacy Game Test Mode explanation

		 Localized string for key “launcher.rosetta.detail.gameTestMode” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaDetailGameTestMode: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.detail.gameTestMode", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Apple software update is installing Rosetta

		 Localized string for key “launcher.rosetta.detail.installing” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaDetailInstalling: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.detail.installing", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Rosetta needs installation

		 Localized string for key “launcher.rosetta.detail.missing” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaDetailMissing: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.detail.missing", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Intel test process cannot start

		 Localized string for key “launcher.rosetta.detail.unavailable” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaDetailUnavailable: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.detail.unavailable", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 General Rosetta unsupported on current macOS

		 Localized string for key “launcher.rosetta.detail.unsupported” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaDetailUnsupported: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.detail.unsupported", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Apple installer exit status follows

		 Localized string for key “launcher.rosetta.failure.installerExited” in table “Launcher.xcstrings”.
		 */
		static func launcherRosettaFailureInstallerExited(_ arg1: String) -> LocalizedStringResource
		{
			LocalizedStringResource(
				"launcher.rosetta.failure.installerExited", defaultValue: "\(arg1)",
				table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Apple Rosetta installer did not start

		 Localized string for key “launcher.rosetta.failure.installerStart” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaFailureInstallerStart: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.failure.installerStart", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Intel compatibility checking status

		 Localized string for key “launcher.rosetta.status.checking” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaStatusChecking: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.status.checking", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Legacy Game Test Mode active status

		 Localized string for key “launcher.rosetta.status.gameTestMode” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaStatusGameTestMode: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.status.gameTestMode", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Rosetta installation failure status

		 Localized string for key “launcher.rosetta.status.installationFailed” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaStatusInstallationFailed: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.status.installationFailed", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Rosetta installation status

		 Localized string for key “launcher.rosetta.status.installing” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaStatusInstalling: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.status.installing", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Rosetta required status

		 Localized string for key “launcher.rosetta.status.missing” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaStatusMissing: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.status.missing", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Intel compatibility unavailable status

		 Localized string for key “launcher.rosetta.status.unavailable” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaStatusUnavailable: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.status.unavailable", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Wine runtime unsupported status

		 Localized string for key “launcher.rosetta.status.unsupported” in table “Launcher.xcstrings”.
		 */
		static var launcherRosettaStatusUnsupported: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.rosetta.status.unsupported", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Time remaining until daily reset; hours then minutes follow

		 Localized string for key “launcher.serverReset.countdown” in table “Launcher.xcstrings”.
		 */
		static func launcherServerResetCountdown(_ arg1: Int, _ arg2: Int)
			-> LocalizedStringResource
		{
			LocalizedStringResource(
				"launcher.serverReset.countdown",
				defaultValue: "\(arg1, specifier: "%lld")\(arg2, specifier: "%02lld")",
				table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Cache cleanup success status

		 Localized string for key “launcher.status.cacheCleared” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusCacheCleared: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.cacheCleared", table: "Launcher", bundle: resourceBundleDescription
			)
		}

		/**
		 Generic checking status

		 Localized string for key “launcher.status.checking” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusChecking: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.checking", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Game download status

		 Localized string for key “launcher.status.downloading” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusDownloading: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.downloading", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Preset gallery cache cleanup success status

		 Localized string for key “launcher.status.galleryCacheCleared” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusGalleryCacheCleared: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.galleryCacheCleared", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Game icon reset success status

		 Localized string for key “launcher.status.gameIconRestored” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusGameIconRestored: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.gameIconRestored", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Game icon success status

		 Localized string for key “launcher.status.gameIconUpdated” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusGameIconUpdated: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.gameIconUpdated", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Selected folder does not contain game executable

		 Localized string for key “launcher.status.gameNotFound” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusGameNotFound: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.gameNotFound", table: "Launcher", bundle: resourceBundleDescription
			)
		}

		/**
		 Launcher and game icons reset success status

		 Localized string for key “launcher.status.iconsRestored” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusIconsRestored: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.iconsRestored", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Launcher and game icon update success status

		 Localized string for key “launcher.status.iconsUpdated” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusIconsUpdated: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.iconsUpdated", table: "Launcher", bundle: resourceBundleDescription
			)
		}

		/**
		 Game can be installed

		 Localized string for key “launcher.status.install” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusInstall: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.install", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Game uninstall moving files to Trash

		 Localized string for key “launcher.status.movingToTrash” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusMovingToTrash: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.movingToTrash", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Download paused status

		 Localized string for key “launcher.status.paused” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusPaused: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.paused", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Download being paused status

		 Localized string for key “launcher.status.pausing” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusPausing: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.pausing", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Preparing game installation

		 Localized string for key “launcher.status.preparing” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusPreparing: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.preparing", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Preparing Wine prefix status

		 Localized string for key “launcher.status.preparingWine” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusPreparingWine: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.preparingWine", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Launcher ready status

		 Localized string for key “launcher.status.ready” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusReady: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.ready", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Game running status

		 Localized string for key “launcher.status.running” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusRunning: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.running", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Settings reset success status

		 Localized string for key “launcher.status.settingsReset” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusSettingsReset: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.settingsReset", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Game starting status

		 Localized string for key “launcher.status.starting” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusStarting: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.starting", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Game stopping status

		 Localized string for key “launcher.status.stopping” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusStopping: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.stopping", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Game removed status

		 Localized string for key “launcher.status.uninstalled” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusUninstalled: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.uninstalled", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Game update available status

		 Localized string for key “launcher.status.updateAvailable” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusUpdateAvailable: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.updateAvailable", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Game updated status

		 Localized string for key “launcher.status.updated” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusUpdated: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.updated", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Game files being verified

		 Localized string for key “launcher.status.verifying” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusVerifying: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.verifying", table: "Launcher", bundle: resourceBundleDescription)
		}

		/**
		 Wine prefix reset success status

		 Localized string for key “launcher.status.wineMigrationDeleted” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusWineMigrationDeleted: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.wineMigrationDeleted", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Wine prefix migration reset success status

		 Localized string for key “launcher.status.wineMigrationPending” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusWineMigrationPending: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.wineMigrationPending", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Wine prefix deletion in progress

		 Localized string for key “launcher.status.winePrefixDeleting” in table “Launcher.xcstrings”.
		 */
		static var launcherStatusWinePrefixDeleting: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.status.winePrefixDeleting", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Launcher update check in progress

		 Localized string for key “launcher.update.status.checking” in table “Launcher.xcstrings”.
		 */
		static var launcherUpdateStatusChecking: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.update.status.checking", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Launcher update check failure

		 Localized string for key “launcher.update.status.failed” in table “Launcher.xcstrings”.
		 */
		static var launcherUpdateStatusFailed: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.update.status.failed", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Launcher update check found no releases

		 Localized string for key “launcher.update.status.noReleases” in table “Launcher.xcstrings”.
		 */
		static var launcherUpdateStatusNoReleases: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.update.status.noReleases", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Launcher update source is not configured

		 Localized string for key “launcher.update.status.sourceUnavailable” in table “Launcher.xcstrings”.
		 */
		static var launcherUpdateStatusSourceUnavailable: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.update.status.sourceUnavailable", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Launcher is on the current version

		 Localized string for key “launcher.update.status.upToDate” in table “Launcher.xcstrings”.
		 */
		static var launcherUpdateStatusUpToDate: LocalizedStringResource {
			LocalizedStringResource(
				"launcher.update.status.upToDate", table: "Launcher",
				bundle: resourceBundleDescription)
		}

		/**
		 Launcher update available; argument is version

		 Localized string for key “launcher.update.status.versionAvailable” in table “Launcher.xcstrings”.
		 */
		static func launcherUpdateStatusVersionAvailable(_ arg1: String) -> LocalizedStringResource
		{
			LocalizedStringResource(
				"launcher.update.status.versionAvailable", defaultValue: "\(arg1)",
				table: "Launcher", bundle: resourceBundleDescription)
		}
	}
}
