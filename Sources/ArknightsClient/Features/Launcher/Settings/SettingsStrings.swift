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
	static let generalSubtitle = "Display, performance, and personalization"
	static let displayControls = "Display & Controls"
	static let rendering = "Rendering"
	static let renderingHelp =
		"Retina: Wine renders at the display's full backing-store resolution.\nMetalFX: Wine renders in macOS points and DXMT upscales every frame 2× with MetalFX spatial scaling. Runtimes without MetalFX support use Lightweight instead.\nLightweight: Wine renders in macOS points and macOS scales the window up.\nApplies on the next game launch."
	static let launcherDisplayControl = "Let the Launcher Size the Game"
	static let launcherDisplayControlDetail =
		"Recommended. The launcher starts the game with the window mode and size below and works out the right resolution for your display. When off, Arknights uses the settings chosen inside the game."
	static let launcherDisplayControlHelp =
		"Arknights' own resolution setting counts the pixels the game draws. With Retina rendering, every window point holds several pixels, so an in-game resolution opens a smaller window than its number suggests. The launcher passes the converted resolution to the game on every start."
	static let gotIt = "Got It"
	static let displayModeFullscreen = "Fullscreen"
	static let displayModeWindowed = "Windowed (Recommended)"
	static let displayModeBorderlessWindow = "Borderless Window"
	static let windowMode = "Window Mode"
	static let windowModeDetail = "How the game window appears the next time it starts."
	static let windowSize = "Window Size"
	static let windowSizeDetail = "The size of the game window on your screen."
	static let windowSizeMenuTitle = "Looks like"
	static let windowSizeHelp =
		"Measured like the resolutions in System Settings › Displays. The launcher works out the resolution the game draws from this size and the Rendering mode."
	static let gameResolution = "Game Resolution"
	static let gameResolutionDetail = "The resolution fullscreen fills your display at."
	static let gameResolutionMenuTitle = "Fills the screen at"
	static let gameResolutionHelp =
		"Fullscreen fills the display with the menu bar. Native matches that display exactly, the sharpest choice; lower resolutions are scaled up to fill it. With MetalFX or Lightweight, the game draws half the width and height and scales the picture up, so every resolution needs less graphics power."
	static let nativeResolution = "Native"

	static func fullscreenResolutionTitle(_ choice: GameFullscreenResolution) -> String {
		switch choice {
		case .native: nativeResolution
		case .fixed(let size): size.displayName
		}
	}

	/// For example "Native (6016 × 3384)", like games label the display's own resolution.
	static func nativeResolutionTitle(_ size: GameDisplaySize?) -> String {
		size.map { "\(nativeResolution) (\($0.displayName))" } ?? nativeResolution
	}

	/// For example "2560 × 1440 (WQHD)"; resolutions without a common name stay plain.
	static func resolutionTitle(_ size: GameDisplaySize) -> String {
		standardName(size).map { "\(size.displayName) (\($0))" } ?? size.displayName
	}

	/// Common names, only for the exact resolutions they stand for.
	static func standardName(_ size: GameDisplaySize) -> String? {
		switch (size.width, size.height) {
		case (1280, 720): "HD"
		case (1920, 1080): "Full HD"
		case (2560, 1440): "WQHD"
		case (3840, 2160): "4K"
		case (5120, 2880): "5K"
		case (6016, 3384): "6K"
		case (7680, 4320): "8K"
		default: nil
		}
	}
	static let launcher = "Launcher"
	static let showGameVersion = "Show Game Version"
	static let showGameVersionDetail =
		"Shows the installed Arknights version and a manual update check above the Play controls."
	static let serverTime = "Server Time & Reset Countdown"
	static let serverTimeDetail =
		"Shows the active server time and time until its next daily reset."
	static let metalHUD = "Metal Performance HUD"
	static let metalHUDDetail =
		"Shows the frame rate and graphics load in the game window during the next game launch."
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
	static let performance = "Performance"
	static let canaryFeatures = "Canary Features"
	static let canaryFeaturesDetail =
		"Enables experimental features and reveals separate permissions for Taiwan and China clients. Disabling it switches a selected Canary client to Global."
	static let chinaClients = "Allow China clients"
	static let chinaClientsDetail =
		"Shows the China and China — Bilibili clients in the region picker."
	static let taiwanClient = "Allow Taiwan client"
	static let taiwanClientDetail =
		"Shows the Taiwan client in the region picker."
	static let hardwareCursor = "Use Mac Pointer"
	static let hardwareCursorDetail =
		"Shows the normal Mac pointer instead of the game's PRTS cursor, so it follows the mouse without delay. Applies on the next game launch."
	static let hardwareCursorHelp =
		"Asks the runtime to hide the game's software-drawn cursor so the macOS hardware cursor shows instead. Runtimes without this capability keep the game cursor."
	static let repair = "Repair"
	static let repairAction = "Repair…"
	static let repairDetail = "Check every game file and download missing or damaged files again."
	static let cacheGallery = "Preset Gallery Caches"
	static let logs = "Logs"
	static let showLogs = "Show Logs"
	static let showGameFilesHelp = "Show game files in Finder"
	static let gameMode = "Game Mode"
	static let gameModeDetail =
		"Asks macOS to give the game priority while it runs. Requires the free Xcode app from the App Store."
	static let gameModeHelp =
		"Uses Apple's gamepolicyctl tool, which ships only inside the full Xcode app, not the Command Line Tools."
	static let gameModeUnavailableDetail =
		"Not available on this Mac: Game Mode needs the free Xcode app from the App Store. Install it, then reopen Settings."
	static let wineSynchronization = "Wine Thread Synchronization"
	static let wineSynchronizationDetail =
		"How the game's background tasks wait for each other. MSYNC runs more smoothly on most Macs; try ESYNC only if the game misbehaves. Applies on the next launch."
	static let wineSynchronizationHelp =
		"Controls how Wine translates Windows thread waits. MSYNC uses macOS Mach synchronization and gave steadier frame pacing in our tests. ESYNC uses Wine's older event-based path and remains the compatibility fallback."
	static let wineSetup = "Wine Setup"
	static let forceMigration = "Run Setup Again"
	static let forceMigrationAction = "Run Setup Again…"
	static let forceMigrationConfirmation = "Run Wine Setup Again on the Next Launch?"
	static let forceMigrationDetail =
		"Sets up the game's Windows environment again on the next launch. Game files and saves are untouched; only that launch takes longer."
	static let forceMigrationHelp =
		"Reruns Wine prefix initialization, DXMT installation, and registry overrides."
	static let resetSettings = "Reset Settings"
	static let resetSettingsAction = "Reset All Settings…"
	static let launcherSettings = "Launcher Settings"
	static let resetSettingsConfirmation = "Reset All Launcher Settings?"
	static let resetSettingsDetail =
		"Resets every launcher setting to its default. Game files, the install location, and the selected region are untouched."
	static let winePrefix = "Wine Prefix"
	static let winePrefixDetail =
		"Deletes the game's Windows environment, including saved Yostar, Google, Apple, and Facebook logins. Game files are untouched; everything else is rebuilt on the next launch."
	static let winePrefixHelp = "Deletes the Wine prefix folder shared by this publisher's regions."
	static let deleteWinePrefix = "Delete Wine Prefix…"
	static let deleteWinePrefixAction = "Delete Wine Prefix"
	static let deleteWinePrefixConfirmation = "Delete the Wine Prefix?"
	static let deleteWinePrefixDetail =
		"This signs you out of every login saved in the sign-in window. Game files are untouched."
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
		"Report problems with the launcher, starting the game, or the sign-in window. The report includes diagnostic details automatically."
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
	static let notAffiliated =
		"This launcher is an independent community project and is not affiliated with Hypergryph, its affiliates, or any third-party publisher."

	static let developerTitle = "Developer"
	static let developerSubtitle = "Preview launcher states safely"
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

	static func verifying(_ percentage: Int) -> String {
		"Verifying \(percentage)%"
	}

	static func downloadSpeed(_ speed: String) -> String {
		"\(speed)"
	}

	static let downloadWaiting = "Waiting for network…"

	static func audioVolumePercent(_ percentage: Int) -> String {
		"\(percentage)%"
	}

	static func renderingMode(_ mode: GameRenderingMode) -> String {
		switch mode {
		case .retina: "Retina (Sharpest)"
		case .metalFX: "MetalFX (Balanced)"
		case .lightweight: "Lightweight (Fastest)"
		}
	}

	static func renderingModeDetail(_ mode: GameRenderingMode) -> String {
		switch mode {
		case .retina:
			"Draws every pixel of a Retina display. The sharpest picture, but it needs the most graphics power."
		case .metalFX:
			"Draws fewer pixels and sharpens the picture with Apple's MetalFX. Smoother in battles; text looks slightly softer."
		case .lightweight:
			"Draws fewer pixels and lets macOS enlarge them. The lightest load, but the picture looks blurry on Retina displays."
		}
	}

	/// Tells players which in-game resolution produces the launcher's window size.
	static func inGameResolutionNote(window: GameDisplaySize, pixelsPerPoint: Int) -> String {
		"Resolutions inside Arknights count the pixels the game draws. With Retina rendering, "
			+ "choose \(window.scaled(by: pixelsPerPoint).displayName) in the game for a "
			+ "\(window.displayName) window."
	}

	/// Says what the player sees first, then what the game draws; `window` is nil in fullscreen.
	static func renderSummary(
		_ plan: GameDisplayPlan, size: GameDisplaySize, window: GameDisplaySize?
	)
		-> String
	{
		let looks = window.map { "Looks like \($0.displayName). " } ?? ""
		let target =
			window == nil ? "fill the screen" : resolutionTitle(size.scaled(by: plan.backingScale))
		let drawn = "\(looks)The game draws \(resolutionTitle(size))"
		return switch plan.scaling {
		case .native: window == nil ? "\(drawn) and fills the screen." : "\(drawn)."
		case .metalFX: "\(drawn) and MetalFX upscales it to \(target)."
		case .stretched: "\(drawn) and macOS stretches it to \(target), which looks softer."
		}
	}

	static func displayMode(_ mode: GameDisplayMode) -> String {
		switch mode {
		case .fullscreen: displayModeFullscreen
		case .windowed: displayModeWindowed
		case .borderlessWindow: displayModeBorderlessWindow
		}
	}
}
