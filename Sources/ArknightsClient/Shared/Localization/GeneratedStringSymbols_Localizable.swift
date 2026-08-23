// SPDX-License-Identifier: MPL-2.0

//
// GeneratedStringSymbols_Localizable.swift
// Auto-Generated symbols for localized strings defined in “Localizable.xcstrings”.
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
	/**
	 Music HUD collapse help

	 Localized string for key “audio.controls.hide” in table “Localizable.xcstrings”.
	 */
	static var audioControlsHide: LocalizedStringResource {
		LocalizedStringResource(
			"audio.controls.hide", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Next playlist track action

	 Localized string for key “audio.controls.next” in table “Localizable.xcstrings”.
	 */
	static var audioControlsNext: LocalizedStringResource {
		LocalizedStringResource(
			"audio.controls.next", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Open current track action

	 Localized string for key “audio.controls.openYouTube” in table “Localizable.xcstrings”.
	 */
	static var audioControlsOpenYouTube: LocalizedStringResource {
		LocalizedStringResource(
			"audio.controls.openYouTube", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Pause music action

	 Localized string for key “audio.controls.pause” in table “Localizable.xcstrings”.
	 */
	static var audioControlsPause: LocalizedStringResource {
		LocalizedStringResource(
			"audio.controls.pause", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Play music action

	 Localized string for key “audio.controls.play” in table “Localizable.xcstrings”.
	 */
	static var audioControlsPlay: LocalizedStringResource {
		LocalizedStringResource(
			"audio.controls.play", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Previous playlist track action

	 Localized string for key “audio.controls.previous” in table “Localizable.xcstrings”.
	 */
	static var audioControlsPrevious: LocalizedStringResource {
		LocalizedStringResource(
			"audio.controls.previous", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Music HUD expand help

	 Localized string for key “audio.controls.show” in table “Localizable.xcstrings”.
	 */
	static var audioControlsShow: LocalizedStringResource {
		LocalizedStringResource(
			"audio.controls.show", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Playlist transition status

	 Localized string for key “audio.status.changingTrack” in table “Localizable.xcstrings”.
	 */
	static var audioStatusChangingTrack: LocalizedStringResource {
		LocalizedStringResource(
			"audio.status.changingTrack", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Music playback status

	 Localized string for key “audio.status.paused” in table “Localizable.xcstrings”.
	 */
	static var audioStatusPaused: LocalizedStringResource {
		LocalizedStringResource(
			"audio.status.paused", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Music status while Arknights is active

	 Localized string for key “audio.status.pausedForGame” in table “Localizable.xcstrings”.
	 */
	static var audioStatusPausedForGame: LocalizedStringResource {
		LocalizedStringResource(
			"audio.status.pausedForGame", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Music playback status

	 Localized string for key “audio.status.playing” in table “Localizable.xcstrings”.
	 */
	static var audioStatusPlaying: LocalizedStringResource {
		LocalizedStringResource(
			"audio.status.playing", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Music volume slider accessibility label

	 Localized string for key “audio.volume.label” in table “Localizable.xcstrings”.
	 */
	static var audioVolumeLabel: LocalizedStringResource {
		LocalizedStringResource(
			"audio.volume.label", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Mute music action

	 Localized string for key “audio.volume.mute” in table “Localizable.xcstrings”.
	 */
	static var audioVolumeMute: LocalizedStringResource {
		LocalizedStringResource(
			"audio.volume.mute", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Muted accessibility value

	 Localized string for key “audio.volume.muted” in table “Localizable.xcstrings”.
	 */
	static var audioVolumeMuted: LocalizedStringResource {
		LocalizedStringResource(
			"audio.volume.muted", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Music volume accessibility value from 0 to 100

	 Localized string for key “audio.volume.percent” in table “Localizable.xcstrings”.
	 */
	static func audioVolumePercent(_ arg1: Int) -> LocalizedStringResource {
		LocalizedStringResource(
			"audio.volume.percent", defaultValue: "\(arg1, specifier: "%lld")",
			table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Unmute music action

	 Localized string for key “audio.volume.unmute” in table “Localizable.xcstrings”.
	 */
	static var audioVolumeUnmute: LocalizedStringResource {
		LocalizedStringResource(
			"audio.volume.unmute", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Install game action

	 Localized string for key “home.action.install” in table “Localizable.xcstrings”.
	 */
	static var homeActionInstall: LocalizedStringResource {
		LocalizedStringResource(
			"home.action.install", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Install game action help; region is Global, Japan, or Korea

	 Localized string for key “home.action.install.help” in table “Localizable.xcstrings”.
	 */
	static func homeActionInstallHelp(_ arg1: String) -> LocalizedStringResource {
		LocalizedStringResource(
			"home.action.install.help", defaultValue: "\(arg1)", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Pause download action

	 Localized string for key “home.action.pause” in table “Localizable.xcstrings”.
	 */
	static var homeActionPause: LocalizedStringResource {
		LocalizedStringResource(
			"home.action.pause", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Pause download action help

	 Localized string for key “home.action.pause.help” in table “Localizable.xcstrings”.
	 */
	static var homeActionPauseHelp: LocalizedStringResource {
		LocalizedStringResource(
			"home.action.pause.help", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Launch game action

	 Localized string for key “home.action.play” in table “Localizable.xcstrings”.
	 */
	static var homeActionPlay: LocalizedStringResource {
		LocalizedStringResource(
			"home.action.play", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Launch game action help

	 Localized string for key “home.action.play.help” in table “Localizable.xcstrings”.
	 */
	static var homeActionPlayHelp: LocalizedStringResource {
		LocalizedStringResource(
			"home.action.play.help", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Resume partial download action

	 Localized string for key “home.action.resume” in table “Localizable.xcstrings”.
	 */
	static var homeActionResume: LocalizedStringResource {
		LocalizedStringResource(
			"home.action.resume", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Resume partial download action help

	 Localized string for key “home.action.resume.help” in table “Localizable.xcstrings”.
	 */
	static var homeActionResumeHelp: LocalizedStringResource {
		LocalizedStringResource(
			"home.action.resume.help", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Stop game action

	 Localized string for key “home.action.stop” in table “Localizable.xcstrings”.
	 */
	static var homeActionStop: LocalizedStringResource {
		LocalizedStringResource(
			"home.action.stop", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Stop game action help

	 Localized string for key “home.action.stop.help” in table “Localizable.xcstrings”.
	 */
	static var homeActionStopHelp: LocalizedStringResource {
		LocalizedStringResource(
			"home.action.stop.help", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Update game action

	 Localized string for key “home.action.update” in table “Localizable.xcstrings”.
	 */
	static var homeActionUpdate: LocalizedStringResource {
		LocalizedStringResource(
			"home.action.update", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Update game action help

	 Localized string for key “home.action.update.help” in table “Localizable.xcstrings”.
	 */
	static var homeActionUpdateHelp: LocalizedStringResource {
		LocalizedStringResource(
			"home.action.update.help", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Retry compatibility check action

	 Localized string for key “home.checkAgain” in table “Localizable.xcstrings”.
	 */
	static var homeCheckAgain: LocalizedStringResource {
		LocalizedStringResource(
			"home.checkAgain", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Visible game download percentage; argument is an integer from 0 to 100

	 Localized string for key “home.download.percentage” in table “Localizable.xcstrings”.
	 */
	static func homeDownloadPercentage(_ arg1: Int) -> LocalizedStringResource {
		LocalizedStringResource(
			"home.download.percentage", defaultValue: "\(arg1, specifier: "%lld")",
			table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Downloaded and total byte counts

	 Localized string for key “home.download.progress” in table “Localizable.xcstrings”.
	 */
	static func homeDownloadProgress(_ arg1: String, _ arg2: String) -> LocalizedStringResource {
		LocalizedStringResource(
			"home.download.progress", defaultValue: "\(arg1)\(arg2)", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Available launcher update button

	 Localized string for key “home.launcherUpdate” in table “Localizable.xcstrings”.
	 */
	static var homeLauncherUpdate: LocalizedStringResource {
		LocalizedStringResource(
			"home.launcherUpdate", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Available launcher update button help

	 Localized string for key “home.launcherUpdate.help” in table “Localizable.xcstrings”.
	 */
	static var homeLauncherUpdateHelp: LocalizedStringResource {
		LocalizedStringResource(
			"home.launcherUpdate.help", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Installed-region menu help

	 Localized string for key “home.region.switch.help” in table “Localizable.xcstrings”.
	 */
	static var homeRegionSwitchHelp: LocalizedStringResource {
		LocalizedStringResource(
			"home.region.switch.help", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Failure reporting action

	 Localized string for key “home.reportProblem” in table “Localizable.xcstrings”.
	 */
	static var homeReportProblem: LocalizedStringResource {
		LocalizedStringResource(
			"home.reportProblem", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Launcher Settings button

	 Localized string for key “home.settings” in table “Localizable.xcstrings”.
	 */
	static var homeSettings: LocalizedStringResource {
		LocalizedStringResource(
			"home.settings", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Settings button help

	 Localized string for key “home.settings.help” in table “Localizable.xcstrings”.
	 */
	static var homeSettingsHelp: LocalizedStringResource {
		LocalizedStringResource(
			"home.settings.help", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Failure status heading

	 Localized string for key “home.status.needsAttention” in table “Localizable.xcstrings”.
	 */
	static var homeStatusNeedsAttention: LocalizedStringResource {
		LocalizedStringResource(
			"home.status.needsAttention", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Game version available for download

	 Localized string for key “home.version.available” in table “Localizable.xcstrings”.
	 */
	static func homeVersionAvailable(_ arg1: String) -> LocalizedStringResource {
		LocalizedStringResource(
			"home.version.available", defaultValue: "\(arg1)", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Manual game update check action

	 Localized string for key “home.version.checkNow” in table “Localizable.xcstrings”.
	 */
	static var homeVersionCheckNow: LocalizedStringResource {
		LocalizedStringResource(
			"home.version.checkNow", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Game update check status

	 Localized string for key “home.version.checking” in table “Localizable.xcstrings”.
	 */
	static var homeVersionChecking: LocalizedStringResource {
		LocalizedStringResource(
			"home.version.checking", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Version HUD collapse help

	 Localized string for key “home.version.hideDetails” in table “Localizable.xcstrings”.
	 */
	static var homeVersionHideDetails: LocalizedStringResource {
		LocalizedStringResource(
			"home.version.hideDetails", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Version HUD expand help

	 Localized string for key “home.version.showDetails” in table “Localizable.xcstrings”.
	 */
	static var homeVersionShowDetails: LocalizedStringResource {
		LocalizedStringResource(
			"home.version.showDetails", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Current game version status

	 Localized string for key “home.version.upToDate” in table “Localizable.xcstrings”.
	 */
	static var homeVersionUpToDate: LocalizedStringResource {
		LocalizedStringResource(
			"home.version.upToDate", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Accessibility label for the active region wordmark

	 Localized string for key “home.wordmark.accessibility” in table “Localizable.xcstrings”.
	 */
	static func homeWordmarkAccessibility(_ arg1: String) -> LocalizedStringResource {
		LocalizedStringResource(
			"home.wordmark.accessibility", defaultValue: "\(arg1)", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Onboarding back navigation action

	 Localized string for key “onboarding.action.back” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionBack: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.back", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Browse artwork presets action

	 Localized string for key “onboarding.action.browsePresets” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionBrowsePresets: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.browsePresets", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Retry a setup preflight check

	 Localized string for key “onboarding.action.checkAgain” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionCheckAgain: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.checkAgain", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Choose a local image action

	 Localized string for key “onboarding.action.chooseImage” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionChooseImage: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.chooseImage", table: "Localizable", bundle: resourceBundleDescription
		)
	}

	/**
	 Choose an operator icon action

	 Localized string for key “onboarding.action.chooseOperator” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionChooseOperator: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.chooseOperator", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Onboarding continue navigation action

	 Localized string for key “onboarding.action.continue” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionContinue: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.continue", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Continue onboarding action after installation is already active

	 Localized string for key “onboarding.action.continueSetup” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionContinueSetup: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.continueSetup", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Finish onboarding action

	 Localized string for key “onboarding.action.finishSetup” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionFinishSetup: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.finishSetup", table: "Localizable", bundle: resourceBundleDescription
		)
	}

	/**
	 Install game and continue onboarding action

	 Localized string for key “onboarding.action.installAndContinue” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionInstallAndContinue: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.installAndContinue", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Install Rosetta 2 action

	 Localized string for key “onboarding.action.installRosetta” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionInstallRosetta: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.installRosetta", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Open a local image selection action

	 Localized string for key “onboarding.action.open” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionOpen: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.open", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Open a launcher problem report action

	 Localized string for key “onboarding.action.reportProblem” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionReportProblem: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.reportProblem", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Resume download and continue onboarding action

	 Localized string for key “onboarding.action.resumeAndContinue” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionResumeAndContinue: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.resumeAndContinue", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Resume game download action

	 Localized string for key “onboarding.action.resumeDownload” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionResumeDownload: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.resumeDownload", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Skip onboarding action

	 Localized string for key “onboarding.action.skipForNow” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionSkipForNow: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.skipForNow", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Retry setup update check action

	 Localized string for key “onboarding.action.tryAgain” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionTryAgain: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.tryAgain", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Retry Rosetta installation action

	 Localized string for key “onboarding.action.tryInstallationAgain” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionTryInstallationAgain: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.tryInstallationAgain", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Restore one default selection action

	 Localized string for key “onboarding.action.useDefault” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionUseDefault: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.useDefault", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Restore default selections action

	 Localized string for key “onboarding.action.useDefaults” in table “Localizable.xcstrings”.
	 */
	static var onboardingActionUseDefaults: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.useDefaults", table: "Localizable", bundle: resourceBundleDescription
		)
	}

	/**
	 Open available launcher version; argument is version

	 Localized string for key “onboarding.action.viewVersion” in table “Localizable.xcstrings”.
	 */
	static func onboardingActionViewVersion(_ arg1: String) -> LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.action.viewVersion", defaultValue: "\(arg1)", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Generic in-progress status

	 Localized string for key “onboarding.common.checking” in table “Localizable.xcstrings”.
	 */
	static var onboardingCommonChecking: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.common.checking", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Personalization artwork section title

	 Localized string for key “onboarding.extras.artwork.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasArtworkTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.artwork.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Background music setting explanation

	 Localized string for key “onboarding.extras.audio.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasAudioDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.audio.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Background music setting title

	 Localized string for key “onboarding.extras.audio.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasAudioTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.audio.title", table: "Localizable", bundle: resourceBundleDescription
		)
	}

	/**
	 Launcher music panel title

	 Localized string for key “onboarding.extras.music.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasMusicTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.music.title", table: "Localizable", bundle: resourceBundleDescription
		)
	}

	/**
	 Now playing HUD setting explanation

	 Localized string for key “onboarding.extras.nowPlaying.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasNowPlayingDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.nowPlaying.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Now playing HUD setting title

	 Localized string for key “onboarding.extras.nowPlaying.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasNowPlayingTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.nowPlaying.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Updates and audio setup subtitle

	 Localized string for key “onboarding.extras.subtitle” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasSubtitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.subtitle", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Updates and audio setup title

	 Localized string for key “onboarding.extras.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.title", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Game update setting explanation

	 Localized string for key “onboarding.extras.updates.game.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasUpdatesGameDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.updates.game.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Game update setting title

	 Localized string for key “onboarding.extras.updates.game.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasUpdatesGameTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.updates.game.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Launcher update setting explanation

	 Localized string for key “onboarding.extras.updates.launcher.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasUpdatesLauncherDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.updates.launcher.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Launcher update setting title

	 Localized string for key “onboarding.extras.updates.launcher.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasUpdatesLauncherTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.updates.launcher.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Project announcements setting explanation

	 Localized string for key “onboarding.extras.updates.notices.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasUpdatesNoticesDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.updates.notices.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Project announcements setting title

	 Localized string for key “onboarding.extras.updates.notices.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasUpdatesNoticesTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.updates.notices.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Updates and notices panel title

	 Localized string for key “onboarding.extras.updates.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasUpdatesTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.updates.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Music volume label

	 Localized string for key “onboarding.extras.volume” in table “Localizable.xcstrings”.
	 */
	static var onboardingExtrasVolume: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.extras.volume", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Community project disclaimer

	 Localized string for key “onboarding.finish.community.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishCommunityDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.community.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Yostar support guidance

	 Localized string for key “onboarding.finish.community.support” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishCommunitySupport: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.community.support", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Community project panel title

	 Localized string for key “onboarding.finish.community.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishCommunityTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.community.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Open Yostar support action

	 Localized string for key “onboarding.finish.contactSupport” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishContactSupport: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.contactSupport", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Finish panel detail while game download is active

	 Localized string for key “onboarding.finish.downloading.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishDownloadingDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.downloading.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Finish panel detail while game is active

	 Localized string for key “onboarding.finish.gameActive.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishGameActiveDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.gameActive.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Finish panel detail while game is installed

	 Localized string for key “onboarding.finish.installed.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishInstalledDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.installed.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Problem report guidance

	 Localized string for key “onboarding.finish.issue.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishIssueDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.issue.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Finish panel detail while installation is paused

	 Localized string for key “onboarding.finish.paused.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishPausedDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.paused.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Finish panel status while download is active

	 Localized string for key “onboarding.finish.status.downloading” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishStatusDownloading: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.status.downloading", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Finish panel status while game is installed

	 Localized string for key “onboarding.finish.status.installed” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishStatusInstalled: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.status.installed", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Finish panel status while installation is paused

	 Localized string for key “onboarding.finish.status.paused” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishStatusPaused: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.status.paused", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Finish panel status while game is active

	 Localized string for key “onboarding.finish.status.running” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishStatusRunning: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.status.running", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Finish setup subtitle

	 Localized string for key “onboarding.finish.subtitle” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishSubtitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.subtitle", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Finish setup title

	 Localized string for key “onboarding.finish.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingFinishTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.finish.title", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Borderless display mode

	 Localized string for key “onboarding.game.displayMode.borderless” in table “Localizable.xcstrings”.
	 */
	static var onboardingGameDisplayModeBorderless: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.displayMode.borderless", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Fullscreen display mode

	 Localized string for key “onboarding.game.displayMode.fullscreen” in table “Localizable.xcstrings”.
	 */
	static var onboardingGameDisplayModeFullscreen: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.displayMode.fullscreen", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Windowed display mode

	 Localized string for key “onboarding.game.displayMode.windowed” in table “Localizable.xcstrings”.
	 */
	static var onboardingGameDisplayModeWindowed: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.displayMode.windowed", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Game-managed display settings explanation

	 Localized string for key “onboarding.game.displaySettings.detail.game” in table “Localizable.xcstrings”.
	 */
	static var onboardingGameDisplaySettingsDetailGame: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.displaySettings.detail.game", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Launcher-managed display settings explanation

	 Localized string for key “onboarding.game.displaySettings.detail.launcher” in table “Localizable.xcstrings”.
	 */
	static var onboardingGameDisplaySettingsDetailLauncher: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.displaySettings.detail.launcher", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Use game display settings toggle title

	 Localized string for key “onboarding.game.displaySettings.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingGameDisplaySettingsTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.displaySettings.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Display settings ownership panel title

	 Localized string for key “onboarding.game.displaySettingsPanel” in table “Localizable.xcstrings”.
	 */
	static var onboardingGameDisplaySettingsPanel: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.displaySettingsPanel", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 High resolution mode explanation

	 Localized string for key “onboarding.game.highResolution.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingGameHighResolutionDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.highResolution.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 High resolution mode toggle title

	 Localized string for key “onboarding.game.highResolution.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingGameHighResolutionTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.highResolution.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Resolution performance guidance

	 Localized string for key “onboarding.game.higherResolution.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingGameHigherResolutionDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.higherResolution.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Pixel density panel title

	 Localized string for key “onboarding.game.pixelDensityPanel” in table “Localizable.xcstrings”.
	 */
	static var onboardingGamePixelDensityPanel: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.pixelDensityPanel", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Resolution field label

	 Localized string for key “onboarding.game.resolution” in table “Localizable.xcstrings”.
	 */
	static var onboardingGameResolution: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.resolution", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Game display setup subtitle

	 Localized string for key “onboarding.game.subtitle” in table “Localizable.xcstrings”.
	 */
	static var onboardingGameSubtitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.subtitle", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Game display setup title

	 Localized string for key “onboarding.game.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingGameTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.title", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Window and resolution panel title

	 Localized string for key “onboarding.game.windowResolutionPanel” in table “Localizable.xcstrings”.
	 */
	static var onboardingGameWindowResolutionPanel: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.game.windowResolutionPanel", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Custom icon overrides explanation

	 Localized string for key “onboarding.icons.custom.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingIconsCustomDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.icons.custom.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Custom icon overrides title

	 Localized string for key “onboarding.icons.custom.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingIconsCustomTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.icons.custom.title", table: "Localizable", bundle: resourceBundleDescription
		)
	}

	/**
	 Dock icon setup subtitle

	 Localized string for key “onboarding.icons.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingIconsDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.icons.detail", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Dock icons panel title

	 Localized string for key “onboarding.icons.dock.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingIconsDockTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.icons.dock.title", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Game icon override menu title

	 Localized string for key “onboarding.icons.game” in table “Localizable.xcstrings”.
	 */
	static var onboardingIconsGame: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.icons.game", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Launcher icon override menu title

	 Localized string for key “onboarding.icons.launcher” in table “Localizable.xcstrings”.
	 */
	static var onboardingIconsLauncher: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.icons.launcher", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Operator icons explanation

	 Localized string for key “onboarding.icons.operator.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingIconsOperatorDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.icons.operator.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Operator icons setting title

	 Localized string for key “onboarding.icons.operator.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingIconsOperatorTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.icons.operator.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Dock icon setup title

	 Localized string for key “onboarding.icons.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingIconsTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.icons.title", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Installation hint before starting a download

	 Localized string for key “onboarding.installation.download.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingInstallationDownloadDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.download.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Installation detail while download is active

	 Localized string for key “onboarding.installation.downloading.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingInstallationDownloadingDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.downloading.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Installation title while download is active

	 Localized string for key “onboarding.installation.downloading.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingInstallationDownloadingTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.downloading.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Existing installation description; first argument is version and second is directory name

	 Localized string for key “onboarding.installation.existing.detail” in table “Localizable.xcstrings”.
	 */
	static func onboardingInstallationExistingDetail(_ arg1: String, _ arg2: String)
		-> LocalizedStringResource
	{
		LocalizedStringResource(
			"onboarding.installation.existing.detail", defaultValue: "\(arg1)\(arg2)",
			table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Existing installation title

	 Localized string for key “onboarding.installation.existing.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingInstallationExistingTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.existing.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Official PC client panel title

	 Localized string for key “onboarding.installation.officialClient” in table “Localizable.xcstrings”.
	 */
	static var onboardingInstallationOfficialClient: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.officialClient", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Partial download verification description

	 Localized string for key “onboarding.installation.partial.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingInstallationPartialDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.partial.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Paused partial download title

	 Localized string for key “onboarding.installation.partial.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingInstallationPartialTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.partial.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Installation size description; argument is formatted byte size

	 Localized string for key “onboarding.installation.ready.detail” in table “Localizable.xcstrings”.
	 */
	static func onboardingInstallationReadyDetail(_ arg1: String) -> LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.ready.detail", defaultValue: "\(arg1)", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Ready-to-install title; argument is region name

	 Localized string for key “onboarding.installation.ready.title” in table “Localizable.xcstrings”.
	 */
	static func onboardingInstallationReadyTitle(_ arg1: String) -> LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.ready.title", defaultValue: "\(arg1)", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Global region description

	 Localized string for key “onboarding.installation.region.detail.global” in table “Localizable.xcstrings”.
	 */
	static var onboardingInstallationRegionDetailGlobal: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.region.detail.global", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Japan region description

	 Localized string for key “onboarding.installation.region.detail.japan” in table “Localizable.xcstrings”.
	 */
	static var onboardingInstallationRegionDetailJapan: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.region.detail.japan", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Korea region description

	 Localized string for key “onboarding.installation.region.detail.korea” in table “Localizable.xcstrings”.
	 */
	static var onboardingInstallationRegionDetailKorea: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.region.detail.korea", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Server region panel title

	 Localized string for key “onboarding.installation.region.panel” in table “Localizable.xcstrings”.
	 */
	static var onboardingInstallationRegionPanel: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.region.panel", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Game region setup subtitle

	 Localized string for key “onboarding.installation.subtitle” in table “Localizable.xcstrings”.
	 */
	static var onboardingInstallationSubtitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.subtitle", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Game region setup title

	 Localized string for key “onboarding.installation.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingInstallationTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.installation.title", table: "Localizable", bundle: resourceBundleDescription
		)
	}

	/**
	 Current launcher artwork accessibility label

	 Localized string for key “onboarding.personalization.artwork.accessibility” in table “Localizable.xcstrings”.
	 */
	static var onboardingPersonalizationArtworkAccessibility: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.personalization.artwork.accessibility", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Dynamic theme setting explanation

	 Localized string for key “onboarding.personalization.dynamicTheme.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingPersonalizationDynamicThemeDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.personalization.dynamicTheme.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Dynamic theme setting title

	 Localized string for key “onboarding.personalization.dynamicTheme.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingPersonalizationDynamicThemeTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.personalization.dynamicTheme.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Server reset countdown setting explanation

	 Localized string for key “onboarding.personalization.reset.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingPersonalizationResetDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.personalization.reset.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Server reset countdown setting title

	 Localized string for key “onboarding.personalization.reset.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingPersonalizationResetTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.personalization.reset.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Theme and status panel title

	 Localized string for key “onboarding.personalization.statusPanel” in table “Localizable.xcstrings”.
	 */
	static var onboardingPersonalizationStatusPanel: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.personalization.statusPanel", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Personalization setup subtitle

	 Localized string for key “onboarding.personalization.subtitle” in table “Localizable.xcstrings”.
	 */
	static var onboardingPersonalizationSubtitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.personalization.subtitle", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Personalization setup title

	 Localized string for key “onboarding.personalization.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingPersonalizationTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.personalization.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Game version HUD setting explanation

	 Localized string for key “onboarding.personalization.version.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingPersonalizationVersionDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.personalization.version.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Game version HUD setting title

	 Localized string for key “onboarding.personalization.version.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingPersonalizationVersionTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.personalization.version.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Onboarding progress rail heading

	 Localized string for key “onboarding.progress.assistant” in table “Localizable.xcstrings”.
	 */
	static var onboardingProgressAssistant: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.progress.assistant", table: "Localizable", bundle: resourceBundleDescription
		)
	}

	/**
	 Updates and audio step title

	 Localized string for key “onboarding.progress.step.extras” in table “Localizable.xcstrings”.
	 */
	static var onboardingProgressStepExtras: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.progress.step.extras", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Finish step title

	 Localized string for key “onboarding.progress.step.finish” in table “Localizable.xcstrings”.
	 */
	static var onboardingProgressStepFinish: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.progress.step.finish", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Game display step title

	 Localized string for key “onboarding.progress.step.game” in table “Localizable.xcstrings”.
	 */
	static var onboardingProgressStepGame: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.progress.step.game", table: "Localizable", bundle: resourceBundleDescription
		)
	}

	/**
	 Icons step title

	 Localized string for key “onboarding.progress.step.icons” in table “Localizable.xcstrings”.
	 */
	static var onboardingProgressStepIcons: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.progress.step.icons", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Region and install step title

	 Localized string for key “onboarding.progress.step.installation” in table “Localizable.xcstrings”.
	 */
	static var onboardingProgressStepInstallation: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.progress.step.installation", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Personalization step title

	 Localized string for key “onboarding.progress.step.personalization” in table “Localizable.xcstrings”.
	 */
	static var onboardingProgressStepPersonalization: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.progress.step.personalization", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Preflight step title

	 Localized string for key “onboarding.progress.step.welcome” in table “Localizable.xcstrings”.
	 */
	static var onboardingProgressStepWelcome: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.progress.step.welcome", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Launcher version label; argument is version

	 Localized string for key “onboarding.progress.version” in table “Localizable.xcstrings”.
	 */
	static func onboardingProgressVersion(_ arg1: String) -> LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.progress.version", defaultValue: "\(arg1)", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Rosetta installation failed status

	 Localized string for key “onboarding.rosetta.failed” in table “Localizable.xcstrings”.
	 */
	static var onboardingRosettaFailed: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.rosetta.failed", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Rosetta installation progress

	 Localized string for key “onboarding.rosetta.installing” in table “Localizable.xcstrings”.
	 */
	static var onboardingRosettaInstalling: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.rosetta.installing", table: "Localizable", bundle: resourceBundleDescription
		)
	}

	/**
	 Rosetta missing explanation

	 Localized string for key “onboarding.rosetta.introduction” in table “Localizable.xcstrings”.
	 */
	static var onboardingRosettaIntroduction: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.rosetta.introduction", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Rosetta manual installation guidance

	 Localized string for key “onboarding.rosetta.manualInstall” in table “Localizable.xcstrings”.
	 */
	static var onboardingRosettaManualInstall: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.rosetta.manualInstall", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Intel compatibility available status

	 Localized string for key “onboarding.welcome.compatibility.available” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeCompatibilityAvailable: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.compatibility.available", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Intel compatibility checking status

	 Localized string for key “onboarding.welcome.compatibility.checking” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeCompatibilityChecking: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.compatibility.checking", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Legacy Game Test Mode recovery guidance

	 Localized string for key “onboarding.welcome.compatibility.gameTestMode” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeCompatibilityGameTestMode: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.compatibility.gameTestMode", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Intel compatibility panel title

	 Localized string for key “onboarding.welcome.compatibility.panel” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeCompatibilityPanel: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.compatibility.panel", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Intel compatibility unavailable guidance

	 Localized string for key “onboarding.welcome.compatibility.unavailable” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeCompatibilityUnavailable: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.compatibility.unavailable", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Unsupported Intel compatibility guidance

	 Localized string for key “onboarding.welcome.compatibility.unsupported” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeCompatibilityUnsupported: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.compatibility.unsupported", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Intel compatibility delayed status

	 Localized string for key “onboarding.welcome.compatibility.waiting” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeCompatibilityWaiting: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.compatibility.waiting", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Launcher language selection description during onboarding

	 Localized string for key “onboarding.welcome.language.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeLanguageDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.language.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 English launcher language option during onboarding

	 Localized string for key “onboarding.welcome.language.english” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeLanguageEnglish: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.language.english", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 German launcher language option during onboarding

	 Localized string for key “onboarding.welcome.language.german” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeLanguageGerman: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.language.german", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Launcher language panel title during onboarding

	 Localized string for key “onboarding.welcome.language.panel” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeLanguagePanel: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.language.panel", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Use the macOS preferred launcher language option during onboarding

	 Localized string for key “onboarding.welcome.language.system” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeLanguageSystem: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.language.system", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Launcher language setting title during onboarding

	 Localized string for key “onboarding.welcome.language.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeLanguageTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.language.title", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Onboarding next steps explanation

	 Localized string for key “onboarding.welcome.next.detail” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeNextDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.next.detail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Onboarding next steps panel title

	 Localized string for key “onboarding.welcome.next.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeNextTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.next.title", table: "Localizable", bundle: resourceBundleDescription
		)
	}

	/**
	 Update check unavailable status title

	 Localized string for key “onboarding.welcome.status.checkFailed” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeStatusCheckFailed: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.status.checkFailed", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Checking launcher updates status title

	 Localized string for key “onboarding.welcome.status.checking” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeStatusChecking: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.status.checking", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Setup ready status title

	 Localized string for key “onboarding.welcome.status.current” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeStatusCurrent: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.status.current", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Launcher current confirmation

	 Localized string for key “onboarding.welcome.status.currentDetail” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeStatusCurrentDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.status.currentDetail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Update check failure guidance

	 Localized string for key “onboarding.welcome.status.failedDetail” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeStatusFailedDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.status.failedDetail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 GitHub releases checking status

	 Localized string for key “onboarding.welcome.status.releaseCheck” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeStatusReleaseCheck: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.status.releaseCheck", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Update required guidance

	 Localized string for key “onboarding.welcome.status.updateDetail” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeStatusUpdateDetail: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.status.updateDetail", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Update required status title

	 Localized string for key “onboarding.welcome.status.updateRequired” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeStatusUpdateRequired: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.status.updateRequired", table: "Localizable",
			bundle: resourceBundleDescription)
	}

	/**
	 Launcher update available; argument is version

	 Localized string for key “onboarding.welcome.status.versionAvailable” in table “Localizable.xcstrings”.
	 */
	static func onboardingWelcomeStatusVersionAvailable(_ arg1: String) -> LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.status.versionAvailable", defaultValue: "\(arg1)",
			table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Onboarding welcome subtitle

	 Localized string for key “onboarding.welcome.subtitle” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeSubtitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.subtitle", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Onboarding welcome title

	 Localized string for key “onboarding.welcome.title” in table “Localizable.xcstrings”.
	 */
	static var onboardingWelcomeTitle: LocalizedStringResource {
		LocalizedStringResource(
			"onboarding.welcome.title", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Standard action that closes a completed modal flow

	 Localized string for key “shared.action.done” in table “Localizable.xcstrings”.
	 */
	static var sharedActionDone: LocalizedStringResource {
		LocalizedStringResource(
			"shared.action.done", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Display name for the Global game region

	 Localized string for key “shared.region.global” in table “Localizable.xcstrings”.
	 */
	static var sharedRegionGlobal: LocalizedStringResource {
		LocalizedStringResource(
			"shared.region.global", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Display name for the Japan game region

	 Localized string for key “shared.region.japan” in table “Localizable.xcstrings”.
	 */
	static var sharedRegionJapan: LocalizedStringResource {
		LocalizedStringResource(
			"shared.region.japan", table: "Localizable", bundle: resourceBundleDescription)
	}

	/**
	 Display name for the Korea game region

	 Localized string for key “shared.region.korea” in table “Localizable.xcstrings”.
	 */
	static var sharedRegionKorea: LocalizedStringResource {
		LocalizedStringResource(
			"shared.region.korea", table: "Localizable", bundle: resourceBundleDescription)
	}
}
