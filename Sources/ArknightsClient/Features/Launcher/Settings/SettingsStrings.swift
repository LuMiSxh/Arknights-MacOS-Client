// SPDX-License-Identifier: MPL-2.0

/// English text owned by the launcher settings experience.
enum SettingsStrings {
	static let navigationLabel = "SETTINGS"
	static let navigationGeneral = "General"
	static let navigationAudio = "Audio"
	static let navigationUpdates = "Updates"
	static let navigationInstallation = "Installation"
	static let navigationStorage = "Storage"
	static let navigationStatistics = "Playtime"
	static let navigationAbout = "About"
	static let navigationDeveloper = "Developer"
	static let dangerZone = "Danger Zone"
	static let game = "Game"
	static let checkNow = "Check Now"
	static let calculating = "Calculating…"
	static let cancel = "Cancel"
	static let choose = "Choose…"
	static let chooseImage = "Choose Image…"
	static let change = "Change…"
	static let show = "Show"
	static let useDefault = "Use Default"
	static let useDefaults = "Use Defaults"

	static let generalTitle = "General"
	static let generalSubtitle = "Display and personalization"
	static let displayControls = "Display & Controls"
	static let highResolution = "High-Resolution Mode"
	static let highResolutionDetail =
		"Uses the display's full pixel density without enlarging the game window."
	static let gameDisplaySettings = "Use In-Game Display Settings"
	static let gameDisplaySettingsDetail =
		"Lets changes made inside Arknights persist between launches."
	static let displayModeFullscreen = "Fullscreen"
	static let displayModeWindowed = "Windowed"
	static let displayModeBorderlessWindow = "Borderless Window (Recommended)"
	static let windowMode = "Window Mode"
	static let windowModeDetail = "Overrides the game window style the next time it starts."
	static let resolution = "Resolution"
	static let resolutionDetail = "Overrides the game resolution the next time it starts."
	static let launcher = "Launcher"
	static let showGameVersion = "Show Game Version"
	static let showGameVersionDetail =
		"Shows the installed Arknights version and a manual update check above the Play controls."
	static let serverTime = "Server Time & Reset Countdown"
	static let serverTimeDetail =
		"Shows the active server time and time until its next daily reset."
	static let metalHUD = "Metal Performance HUD"
	static let metalHUDDetail =
		"Shows Apple's native FPS and GPU overlay during the next game launch."
	static let setupAssistant = "Setup Assistant"
	static let setupAssistantDetail =
		"Run the guided region, display, and personalization setup again."
	static let runAgain = "Run Again…"
	static let personalization = "Personalization"
	static let artwork = "Artwork"
	static let artworkDetail = "Background shown behind the launcher controls."
	static let presets = "Presets…"
	static let operatorIcons = "Operator Icons"
	static let operatorIconsDetail =
		"Use one operator for the Launcher and for a Game icon in the original Arknights style."
	static let chooseOperator = "Choose Operator…"
	static let customIconOverrides = "Custom Icon Overrides"
	static let customIconOverridesDetail =
		"Use separate local images instead of the generated operator pair."
	static let dynamicTheme = "Dynamic Theme"
	static let dynamicThemeDetail =
		"Automatically changes the launcher colors and generated operator icon pair to match the selected background."

	static let audioTitle = "Audio"
	static let audioSubtitle = "Background music playback"
	static let audioMusic = "Music"
	static let audioBackgroundMusic = "Play Background Music"
	static let audioBackgroundMusicDetail =
		"Plays music while the launcher is open and the game is not running."
	static let audioURL = "Music URL"
	static let audioURLDetail = "YouTube video or playlist link."
	static let audioURLPrompt = "https://www.youtube.com/playlist?..."
	static let audioVolume = "Volume"
	static let audioVolumeDetail = "Sets the launcher music playback level."
	static let audioCurrentlyPlaying = "Show Currently Playing"
	static let audioCurrentlyPlayingDetail =
		"Shows the current track and expandable playback controls above the launcher controls."

	static let updatesTitle = "Updates"
	static let updatesSubtitle = "Keep the launcher and game current"
	static let automaticChecks = "Automatic Checks"
	static let announcements = "Announcements"
	static let announcementsDetail = "Show occasional project messages once per announcement."
	static let checking = "Checking…"
	static let updateAvailable = "Update available"

	static let installationTitle = "Installation"
	static let installationSubtitle = "Files, repair, and removal"
	static let region = "Region"
	static let regionDetail = "Each region installs, updates, and launches independently."
	static let location = "Location"
	static let status = "Status"
	static let statusDetail = "State of the selected region's game installation."
	static let installationLocation = "Installation Location"
	static let installationLocationDetail =
		"Choose a new folder or adopt an existing game installation."
	static let folder = "Folder"
	static let chooseNewLocation = "Choose New Location…"
	static let locateExisting = "Locate Existing Installation…"
	static let maintenance = "Maintenance"
	static let compatibility = "Compatibility"
	static let canaryFeatures = "Canary Features"
	static let canaryFeaturesDetail =
		"Enables experimental features and reveals separate permissions for Taiwan and China clients. Disabling it switches a selected Canary client to Global."
	static let chinaClients = "Allow China clients"
	static let chinaClientsDetail =
		"Exposes the China clients in the region picker. They stay disabled until you allow them here."
	static let taiwanClient = "Allow Taiwan client"
	static let taiwanClientDetail =
		"Exposes the Taiwan client in the region picker. It stays disabled until you allow it here."
	static let frameLatency = "Frame Latency"
	static let frameLatencyDetail =
		"Limits the DXMT queue to 1–3 frames. Lower values may reduce cursor latency but can make presentation less smooth. Applies on the next game launch."
	static let repair = "Repair"
	static let repairAction = "Repair…"
	static let repairDetail = "Check every game file and download missing or damaged files again."
	static let cacheGallery = "Preset Gallery Caches"
	static let logs = "Logs"
	static let showLogs = "Show Logs"
	static let showGameFilesHelp = "Show game files in Finder"
	static let gameMode = "Game Mode (Experimental)"
	static let gameModeDetail =
		"Asks macOS to prioritize the game while it runs. Needs the full Xcode app installed, since only Xcode ships the tool this requires."
	static let gameModeAlert = "Game Mode Needs Xcode"
	static let gameModeAlertDetail =
		"This requires Apple's gamepolicyctl tool, which only ships inside the full Xcode app, not the Command Line Tools. Install Xcode from the App Store to use it."
	static let wineSynchronization = "Wine Thread Synchronization"
	static let wineSynchronizationDetail =
		"Controls how Wine translates Windows thread waits. MSYNC uses macOS Mach synchronization and gave steadier frame pacing in our tests. ESYNC uses Wine's older event-based path and remains the compatibility fallback. Applies on the next launch."
	static let wineSetup = "Wine Setup"
	static let forceMigration = "Force Migration"
	static let forceMigrationAction = "Force Migration…"
	static let forceMigrationConfirmation = "Force Wine Setup to Run Again?"
	static let forceMigrationDetail =
		"Redo Wine initialization, DXMT installation, and registry overrides on the next launch. Game files and saves are untouched; only the next launch takes longer."
	static let resetSettings = "Reset Settings"
	static let resetSettingsAction = "Reset All Settings…"
	static let launcherSettings = "Launcher Settings"
	static let resetSettingsConfirmation = "Reset All Launcher Settings?"
	static let resetSettingsDetail =
		"Reset every toggle and option on this screen to default. The install location and selected region are untouched."
	static let winePrefix = "Wine Prefix"
	static let winePrefixDetail =
		"Delete the entire Wine environment, including saved Yostar, Google, Apple, and Facebook logins. Game files are untouched; everything else rebuilds on the next launch."
	static let deleteWinePrefix = "Delete Wine Prefix…"
	static let deleteWinePrefixAction = "Delete Wine Prefix"
	static let deleteWinePrefixConfirmation = "Delete the Wine Prefix?"
	static let deleteWinePrefixDetail =
		"This signs you out of every login saved in the embedded browser. Game files are untouched."
	static let gameFiles = "Game files"
	static let gameFilesDetail = "Move the selected game installation to the Trash."
	static let uninstall = "Uninstall Game…"
	static let uninstallConfirmation = "Uninstall Arknights?"
	static let uninstallDetail = "The launcher stays installed."
	static let moveGameToTrash = "Move Game to Trash"
	static let installed = "Installed"
	static let paused = "Paused"
	static let notInstalled = "Not installed"
	static let preparingDownload = "Preparing download"

	static let aboutTitle = "About"
	static let application = "Arknights Client"
	static let unofficialLauncher = "Unofficial macOS launcher"
	static let openFinder = "Show in Finder"
	static let openFinderHelp = "Reveal the launcher application in Finder"
	static let github = "GitHub"
	static let githubHelp = "Open project repository"
	static let donate = "Donate"
	static let donateHelp = "Support the project on Ko-fi"
	static let documents = "Documents"
	static let changelog = "Changelog"
	static let license = "MPL-2.0 License"
	static let thirdPartyNotices = "Third-Party Notices"
	static let support = "Support"
	static let launcherIssues = "Launcher Issues"
	static let launcherIssuesDetail =
		"Report launcher, Wine runtime, or embedded browser problems with generated diagnostics."
	static let report = "Report…"
	static let gameAccountIssues = "Game & Account Issues"
	static let gameAccountIssuesDetail =
		"Contact Yostar for account, payment, or game-service problems."
	static let contactYostar = "Contact Yostar…"
	static func contactPublisherTitle(region: GameRegion) -> String {
		if region.publisher == .gryphline {
			return "Contact Gryphline…"
		}
		if region.publisher == .hypergryph {
			return "Contact Hypergryph…"
		}
		return contactYostar
	}
	static func gameAccountIssuesDetail(region: GameRegion) -> String {
		if region.publisher == .gryphline {
			return "Contact Gryphline for account, payment, or game-service problems."
		}
		if region.publisher == .hypergryph {
			return "Contact Hypergryph for account, payment, or game-service problems."
		}
		return gameAccountIssuesDetail
	}
	static let userAgreement = "User Agreement"
	static let privacyPolicy = "Privacy Policy"
	static let notAffiliated = "This launcher is not affiliated with Hypergryph or Yostar."

	static let developerTitle = "Developer"
	static let developerSubtitle = "Preview launcher states safely"
	static let developerScenario = "Scenario"
	static let developerCustomPopup = "Custom Popup"
	static let developerCustomPopupTitle = "Title"
	static let developerShowPopup = "Show Popup"
	static let developerIsolation = "Isolation"
	static let developerIsolationDetail =
		"Game actions only move between simulated states. The preview uses separate temporary paths and preferences."

	static func cacheGalleryDetail(_ size: String) -> String {
		"Clear cached preset metadata and all downloaded gallery assets (avatars + wallpapers). They currently use \(size)."
	}

	static func downloading(_ percentage: Int) -> String {
		"Downloading \(percentage)%"
	}

	static func downloadSpeed(_ speed: String) -> String {
		"\(speed)"
	}

	static let downloadWaiting = "Waiting for network…"

	static func audioVolumePercent(_ percentage: Int) -> String {
		"\(percentage)%"
	}

	static func displayMode(_ mode: GameDisplayMode) -> String {
		switch mode {
		case .fullscreen: displayModeFullscreen
		case .windowed: displayModeWindowed
		case .borderlessWindow: displayModeBorderlessWindow
		}
	}
}
