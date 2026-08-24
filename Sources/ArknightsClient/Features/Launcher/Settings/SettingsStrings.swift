// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Localized text owned by the launcher settings experience.
enum SettingsStrings {
	static let navigationLabel = LocalizedStringResource.Settings.settingsNavigationLabel
	static let navigationGeneral = LocalizedStringResource.Settings.settingsNavigationGeneral
	static let navigationAudio = LocalizedStringResource.Settings.settingsNavigationAudio
	static let navigationUpdates = LocalizedStringResource.Settings.settingsNavigationUpdates
	static let navigationInstallation = LocalizedStringResource.Settings
		.settingsNavigationInstallation
	static let navigationAbout = LocalizedStringResource.Settings.settingsNavigationAbout
	static let navigationDeveloper = LocalizedStringResource.Settings.settingsNavigationDeveloper
	static let dangerZone = LocalizedStringResource.Settings.settingsCommonDangerZone
	static let game = LocalizedStringResource.Settings.settingsCommonGame
	static let checkNow = LocalizedStringResource.Settings.settingsCommonCheckNow
	static let calculating = LocalizedStringResource.Settings.settingsCommonCalculating
	static let cancel = LocalizedStringResource.Settings.settingsCommonCancel
	static let choose = LocalizedStringResource.Settings.settingsCommonChoose
	static let chooseImage = LocalizedStringResource.Settings.settingsCommonChooseImage
	static let change = LocalizedStringResource.Settings.settingsCommonChange
	static let clearCache = LocalizedStringResource.Settings.settingsCommonClearCache
	static let show = LocalizedStringResource.Settings.settingsCommonShow
	static let useDefault = LocalizedStringResource.Settings.settingsCommonUseDefault
	static let useDefaults = LocalizedStringResource.Settings.settingsCommonUseDefaults

	static let generalTitle = LocalizedStringResource.Settings.settingsGeneralTitle
	static let generalSubtitle = LocalizedStringResource.Settings.settingsGeneralSubtitle
	static let displayControls = LocalizedStringResource.Settings.settingsGeneralDisplayControls
	static let highResolution = LocalizedStringResource.Settings.settingsGeneralHighResolution
	static let highResolutionDetail = LocalizedStringResource.Settings
		.settingsGeneralHighResolutionDetail
	static let gameDisplaySettings = LocalizedStringResource.Settings
		.settingsGeneralGameDisplaySettings
	static let gameDisplaySettingsDetail = LocalizedStringResource.Settings
		.settingsGeneralGameDisplaySettingsDetail
	static let displayModeFullscreen = LocalizedStringResource.Settings
		.settingsGeneralDisplayModeFullscreen
	static let displayModeWindowed = LocalizedStringResource.Settings
		.settingsGeneralDisplayModeWindowed
	static let displayModeBorderlessWindow = LocalizedStringResource.Settings
		.settingsGeneralDisplayModeBorderlessWindow
	static let windowMode = LocalizedStringResource.Settings.settingsGeneralWindowMode
	static let windowModeDetail = LocalizedStringResource.Settings.settingsGeneralWindowModeDetail
	static let resolution = LocalizedStringResource.Settings.settingsGeneralResolution
	static let resolutionDetail = LocalizedStringResource.Settings.settingsGeneralResolutionDetail
	static let launcher = LocalizedStringResource.Settings.settingsGeneralLauncher
	static let language = LocalizedStringResource.Settings.settingsGeneralLanguage
	static let languageDetail = LocalizedStringResource.Settings.settingsGeneralLanguageDetail
	static let languageSystem = LocalizedStringResource.Settings.settingsGeneralLanguageSystem
	static let languageEnglish = LocalizedStringResource.Settings.settingsGeneralLanguageEnglish
	static let languageGerman = LocalizedStringResource.Settings.settingsGeneralLanguageGerman
	static let showGameVersion = LocalizedStringResource.Settings.settingsGeneralShowGameVersion
	static let showGameVersionDetail = LocalizedStringResource.Settings
		.settingsGeneralShowGameVersionDetail
	static let serverTime = LocalizedStringResource.Settings.settingsGeneralServerTime
	static let serverTimeDetail = LocalizedStringResource.Settings.settingsGeneralServerTimeDetail
	static let metalHUD = LocalizedStringResource.Settings.settingsGeneralMetalHUD
	static let metalHUDDetail = LocalizedStringResource.Settings.settingsGeneralMetalHUDDetail
	static let setupAssistant = LocalizedStringResource.Settings.settingsGeneralSetupAssistant
	static let setupAssistantDetail = LocalizedStringResource.Settings
		.settingsGeneralSetupAssistantDetail
	static let runAgain = LocalizedStringResource.Settings.settingsGeneralRunAgain
	static let personalization = LocalizedStringResource.Settings.settingsGeneralPersonalization
	static let artwork = LocalizedStringResource.Settings.settingsGeneralArtwork
	static let artworkDetail = LocalizedStringResource.Settings.settingsGeneralArtworkDetail
	static let presets = LocalizedStringResource.Settings.settingsGeneralPresets
	static let operatorIcons = LocalizedStringResource.Settings.settingsGeneralOperatorIcons
	static let operatorIconsDetail = LocalizedStringResource.Settings
		.settingsGeneralOperatorIconsDetail
	static let chooseOperator = LocalizedStringResource.Settings.settingsGeneralChooseOperator
	static let customIconOverrides = LocalizedStringResource.Settings
		.settingsGeneralCustomIconOverrides
	static let customIconOverridesDetail = LocalizedStringResource.Settings
		.settingsGeneralCustomIconOverridesDetail
	static let dynamicTheme = LocalizedStringResource.Settings.settingsGeneralDynamicTheme
	static let dynamicThemeDetail = LocalizedStringResource.Settings
		.settingsGeneralDynamicThemeDetail

	static func appLanguage(_ language: AppLanguage) -> LocalizedStringResource {
		switch language {
		case .system: languageSystem
		case .english: languageEnglish
		case .german: languageGerman
		}
	}

	static let audioTitle = LocalizedStringResource.Settings.settingsAudioTitle
	static let audioSubtitle = LocalizedStringResource.Settings.settingsAudioSubtitle
	static let audioMusic = LocalizedStringResource.Settings.settingsAudioMusic
	static let audioBackgroundMusic = LocalizedStringResource.Settings.settingsAudioBackgroundMusic
	static let audioBackgroundMusicDetail = LocalizedStringResource.Settings
		.settingsAudioBackgroundMusicDetail
	static let audioURL = LocalizedStringResource.Settings.settingsAudioUrl
	static let audioURLDetail = LocalizedStringResource.Settings.settingsAudioUrlDetail
	static let audioURLPrompt = LocalizedStringResource.Settings.settingsAudioUrlPrompt
	static let audioVolume = LocalizedStringResource.Settings.settingsAudioVolume
	static let audioVolumeDetail = LocalizedStringResource.Settings.settingsAudioVolumeDetail
	static let audioCurrentlyPlaying = LocalizedStringResource.Settings
		.settingsAudioCurrentlyPlaying
	static let audioCurrentlyPlayingDetail = LocalizedStringResource.Settings
		.settingsAudioCurrentlyPlayingDetail

	static let updatesTitle = LocalizedStringResource.Settings.settingsUpdatesTitle
	static let updatesSubtitle = LocalizedStringResource.Settings.settingsUpdatesSubtitle
	static let automaticChecks = LocalizedStringResource.Settings.settingsUpdatesAutomaticChecks
	static let announcements = LocalizedStringResource.Settings.settingsUpdatesAnnouncements
	static let announcementsDetail = LocalizedStringResource.Settings
		.settingsUpdatesAnnouncementsDetail
	static let checking = LocalizedStringResource.Settings.settingsUpdatesChecking
	static let updateAvailable = LocalizedStringResource.Settings.settingsUpdatesUpdateAvailable

	static let installationTitle = LocalizedStringResource.Settings.settingsInstallationTitle
	static let installationSubtitle = LocalizedStringResource.Settings.settingsInstallationSubtitle
	static let region = LocalizedStringResource.Settings.settingsInstallationRegion
	static let regionDetail = LocalizedStringResource.Settings.settingsInstallationRegionDetail
	static let location = LocalizedStringResource.Settings.settingsInstallationLocation
	static let status = LocalizedStringResource.Settings.settingsInstallationStatus
	static let statusDetail = LocalizedStringResource.Settings.settingsInstallationStatusDetail
	static let installationLocation = LocalizedStringResource.Settings
		.settingsInstallationInstallationLocation
	static let installationLocationDetail = LocalizedStringResource.Settings
		.settingsInstallationInstallationLocationDetail
	static let folder = LocalizedStringResource.Settings.settingsInstallationFolder
	static let chooseNewLocation = LocalizedStringResource.Settings
		.settingsInstallationChooseNewLocation
	static let locateExisting = LocalizedStringResource.Settings.settingsInstallationLocateExisting
	static let maintenance = LocalizedStringResource.Settings.settingsInstallationMaintenance
	static let repair = LocalizedStringResource.Settings.settingsInstallationRepair
	static let repairAction = LocalizedStringResource.Settings.settingsInstallationRepairAction
	static let repairDetail = LocalizedStringResource.Settings.settingsInstallationRepairDetail
	static let cacheGallery = LocalizedStringResource.Settings.settingsInstallationCacheGallery
	static let logs = LocalizedStringResource.Settings.settingsInstallationLogs
	static let logsDetail = LocalizedStringResource.Settings.settingsInstallationLogsDetail
	static let showLogs = LocalizedStringResource.Settings.settingsInstallationShowLogs
	static let showGameFilesHelp = LocalizedStringResource.Settings
		.settingsInstallationShowGameFilesHelp
	static let gameMode = LocalizedStringResource.Settings.settingsInstallationGameMode
	static let gameModeDetail = LocalizedStringResource.Settings.settingsInstallationGameModeDetail
	static let gameModeAlert = LocalizedStringResource.Settings.settingsInstallationGameModeAlert
	static let gameModeAlertDetail = LocalizedStringResource.Settings
		.settingsInstallationGameModeAlertDetail
	static let wineSynchronization = LocalizedStringResource.Settings
		.settingsInstallationWineSynchronization
	static let wineSynchronizationDetail = LocalizedStringResource.Settings
		.settingsInstallationWineSynchronizationDetail
	static let wineSetup = LocalizedStringResource.Settings.settingsInstallationWineSetup
	static let forceMigration = LocalizedStringResource.Settings.settingsInstallationForceMigration
	static let forceMigrationAction = LocalizedStringResource.Settings
		.settingsInstallationForceMigrationAction
	static let forceMigrationConfirmation = LocalizedStringResource.Settings
		.settingsInstallationForceMigrationConfirmation
	static let forceMigrationDetail = LocalizedStringResource.Settings
		.settingsInstallationForceMigrationDetail
	static let resetSettings = LocalizedStringResource.Settings.settingsInstallationResetSettings
	static let resetSettingsAction = LocalizedStringResource.Settings
		.settingsInstallationResetSettingsAction
	static let launcherSettings = LocalizedStringResource.Settings
		.settingsInstallationLauncherSettings
	static let resetSettingsConfirmation = LocalizedStringResource.Settings
		.settingsInstallationResetSettingsConfirmation
	static let resetSettingsDetail = LocalizedStringResource.Settings
		.settingsInstallationResetSettingsDetail
	static let winePrefix = LocalizedStringResource.Settings.settingsInstallationWinePrefix
	static let winePrefixDetail = LocalizedStringResource.Settings
		.settingsInstallationWinePrefixDetail
	static let deleteWinePrefix = LocalizedStringResource.Settings
		.settingsInstallationWinePrefixDelete
	static let deleteWinePrefixAction = LocalizedStringResource.Settings
		.settingsInstallationWinePrefixDeleteAction
	static let deleteWinePrefixConfirmation = LocalizedStringResource.Settings
		.settingsInstallationWinePrefixDeleteConfirmation
	static let deleteWinePrefixDetail = LocalizedStringResource.Settings
		.settingsInstallationWinePrefixDeleteDetail
	static let gameFiles = LocalizedStringResource.Settings.settingsInstallationGameFiles
	static let gameFilesDetail = LocalizedStringResource.Settings
		.settingsInstallationGameFilesDetail
	static let uninstall = LocalizedStringResource.Settings.settingsInstallationUninstall
	static let uninstallConfirmation = LocalizedStringResource.Settings
		.settingsInstallationUninstallConfirmation
	static let uninstallDetail = LocalizedStringResource.Settings
		.settingsInstallationUninstallDetail
	static let moveGameToTrash = LocalizedStringResource.Settings
		.settingsInstallationUninstallMoveToTrash
	static let installed = LocalizedStringResource.Settings.settingsInstallationInstalled
	static let paused = LocalizedStringResource.Settings.settingsInstallationPaused
	static let notInstalled = LocalizedStringResource.Settings.settingsInstallationNotInstalled
	static let preparingDownload = LocalizedStringResource.Settings
		.settingsInstallationPreparingDownload

	static let aboutTitle = LocalizedStringResource.Settings.settingsAboutTitle
	static let application = LocalizedStringResource.Settings.settingsAboutApplication
	static let unofficialLauncher = LocalizedStringResource.Settings.settingsAboutUnofficialLauncher
	static let openFinder = LocalizedStringResource.Settings.settingsAboutOpenFinder
	static let openFinderHelp = LocalizedStringResource.Settings.settingsAboutOpenFinderHelp
	static let github = LocalizedStringResource.Settings.settingsAboutGithub
	static let githubHelp = LocalizedStringResource.Settings.settingsAboutGithubHelp
	static let documents = LocalizedStringResource.Settings.settingsAboutDocuments
	static let changelog = LocalizedStringResource.Settings.settingsAboutChangelog
	static let license = LocalizedStringResource.Settings.settingsAboutLicense
	static let thirdPartyNotices = LocalizedStringResource.Settings.settingsAboutThirdPartyNotices
	static let support = LocalizedStringResource.Settings.settingsAboutSupport
	static let launcherIssues = LocalizedStringResource.Settings.settingsAboutLauncherIssues
	static let launcherIssuesDetail = LocalizedStringResource.Settings
		.settingsAboutLauncherIssuesDetail
	static let report = LocalizedStringResource.Settings.settingsAboutReport
	static let gameAccountIssues = LocalizedStringResource.Settings.settingsAboutGameAccountIssues
	static let gameAccountIssuesDetail = LocalizedStringResource.Settings
		.settingsAboutGameAccountIssuesDetail
	static let contactYostar = LocalizedStringResource.Settings.settingsAboutContactYostar
	static let userAgreement = LocalizedStringResource.Settings.settingsAboutUserAgreement
	static let privacyPolicy = LocalizedStringResource.Settings.settingsAboutPrivacyPolicy
	static let notAffiliated = LocalizedStringResource.Settings.settingsAboutNotAffiliated

	static let developerTitle = LocalizedStringResource.Settings.settingsDeveloperTitle
	static let developerSubtitle = LocalizedStringResource.Settings.settingsDeveloperSubtitle
	static let developerScenario = LocalizedStringResource.Settings.settingsDeveloperScenario
	static let developerCustomPopup = LocalizedStringResource.Settings.settingsDeveloperCustomPopup
	static let developerCustomPopupTitle = LocalizedStringResource.Settings
		.settingsDeveloperCustomPopupTitle
	static let developerShowPopup = LocalizedStringResource.Settings.settingsDeveloperShowPopup
	static let developerIsolation = LocalizedStringResource.Settings.settingsDeveloperIsolation
	static let developerIsolationDetail = LocalizedStringResource.Settings
		.settingsDeveloperIsolationDetail

	static func cacheDetail(_ size: String) -> LocalizedStringResource {
		LocalizedStringResource.Settings.settingsInstallationCacheDetail(size)
	}

	static func cacheGalleryDetail(_ size: String) -> LocalizedStringResource {
		LocalizedStringResource.Settings.settingsInstallationCacheGalleryDetail(size)
	}

	static func downloading(_ percentage: Int) -> LocalizedStringResource {
		LocalizedStringResource.Settings.settingsInstallationDownloading(percentage)
	}

	static func downloadSpeed(_ speed: String) -> LocalizedStringResource {
		LocalizedStringResource.Settings.settingsInstallationDownloadSpeed(speed)
	}

	static let downloadWaiting = LocalizedStringResource.Settings
		.settingsInstallationDownloadWaiting

	static func audioVolumePercent(_ percentage: Int) -> LocalizedStringResource {
		LocalizedStringResource.Settings.settingsAudioVolumePercent(percentage)
	}

	static func displayMode(_ mode: GameDisplayMode) -> LocalizedStringResource {
		switch mode {
		case .fullscreen: displayModeFullscreen
		case .windowed: displayModeWindowed
		case .borderlessWindow: displayModeBorderlessWindow
		}
	}
}
