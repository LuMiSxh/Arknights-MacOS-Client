// SPDX-License-Identifier: MPL-2.0

/// English text owned by the launcher settings experience. Titles and details speak to players;
/// technical background lives in `*Help` tooltips and the Advanced game panel.
enum SettingsStrings {
	static let navigationLabel = "SETTINGS"
	static let navigationGame = "Game"
	static let navigationAppearance = "Appearance"
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

	static let gameTitle = "Game"
	static let gameSubtitle = "How Arknights looks and plays"
	static let displayPanel = "Display"
	static let advancedPanel = "Advanced"
	static let gotIt = "Got It"

	static let showTheGame = "Show the game"
	static let showTheGameHelp = "Applies the next time the game starts."

	static func displayMode(_ mode: GameDisplayMode) -> String {
		switch mode {
		case .fullscreen: "Fullscreen"
		case .windowed: "In a window"
		case .borderlessWindow: "Borderless window"
		}
	}

	static func displayModeDetail(_ mode: GameDisplayMode) -> String {
		switch mode {
		case .fullscreen: "Arknights fills your whole screen."
		case .windowed: "Arknights opens in a window you can move around."
		case .borderlessWindow: "Arknights opens in a window without a title bar."
		}
	}

	static let windowSize = "Window size"
	static let windowSizeHelp =
		"Measured like the resolutions in System Settings › Displays. The launcher works out the resolution the game draws from this size and the Picture setting."
	static let exactSizeMenuTitle = "Exact size"

	static func windowSizeTitle(_ choice: GameWindowSizeChoice) -> String {
		switch choice {
		case .fillScreen: "Fill my screen"
		case .leaveRoom: "Leave room for other apps"
		}
	}

	/// `choice` is nil for an exact size picked from the list.
	static func windowSizeDetail(_ choice: GameWindowSizeChoice?) -> String {
		switch choice {
		case .fillScreen?: "Fills your screen, title bar included."
		case .leaveRoom?: "Leaves space for other apps on your screen."
		case nil: "A window of the exact size you picked."
		}
	}

	static let fullscreenDetail = "Detail"
	static let fullscreenDetailHelp =
		"Fullscreen fills the display with the menu bar. Full detail matches that display exactly, the sharpest choice; lower resolutions are scaled up to fill it. With the Smooth and Battery picture settings, the game draws half the width and height and scales the picture up, so every resolution needs less graphics power."
	static let exactResolution = "Exact resolution"

	/// For example "Balanced · 2560 × 1440 (WQHD)".
	static func fullscreenDetailTitle(
		_ detail: GameFullscreenDetail, resolution: GameFullscreenResolution
	) -> String {
		let size =
			switch resolution {
			case .native: nativeResolution
			case .fixed(let size): resolutionTitle(size)
			}
		return switch detail {
		case .full: "Full detail · \(size) (recommended)"
		case .balanced: "Balanced · \(size)"
		case .lighter: "Lighter · \(size)"
		}
	}

	/// `detail` is nil for an exact resolution picked from the submenu.
	static func fullscreenDetailDetail(_ detail: GameFullscreenDetail?) -> String {
		switch detail {
		case .full?: "Uses every pixel of your screen. Best on most Macs."
		case .balanced?: "A little easier on your Mac, still crisp."
		case .lighter?: "Easiest on your Mac, but the picture looks softer."
		case nil: "A resolution you picked yourself."
		}
	}

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

	static let picture = "Picture"
	static let pictureHelp =
		"Retina: Wine renders at the display's full backing-store resolution.\nMetalFX: Wine renders in macOS points and DXMT upscales every frame 2× with MetalFX spatial scaling. Runtimes without MetalFX support use Lightweight instead.\nLightweight: Wine renders in macOS points and macOS scales the window up.\nApplies on the next game launch."

	static func pictureTitle(_ mode: GameRenderingMode) -> String {
		switch mode {
		case .retina: "The sharpest picture · Retina"
		case .metalFX: "Smooth play on big screens · MetalFX"
		case .lightweight: "Longer battery life · Lightweight"
		}
	}

	static func pictureDetail(_ mode: GameRenderingMode) -> String {
		switch mode {
		case .retina: "Looks sharpest, but asks the most of your Mac."
		case .metalFX: "Stays smooth on large screens; text looks slightly softer."
		case .lightweight: "Easiest on your battery, but the picture looks softer."
		}
	}

	static let pointer = "Pointer"
	static let pointerHelp =
		"Asks the runtime to hide the game's software-drawn cursor so the macOS hardware cursor shows instead. Runtimes without this capability keep the game cursor. Applies on the next game launch."
	static let macPointer = "Your Mac's pointer"
	static let gamePointer = "Arknights' cursor"

	static func pointerDetail(usesMacPointer: Bool) -> String {
		usesMacPointer
			? "The macOS hardware cursor follows your mouse without delay."
			: "The game draws its own software cursor, which can lag slightly."
	}

	static let launcherDisplayControl = "Let the launcher size the game"
	static let launcherDisplayControlDetail =
		"Recommended. The launcher starts the game with the display choices above. When off, Arknights uses the settings chosen inside the game."
	static let launcherDisplayControlHelp =
		"Arknights' own resolution setting counts the pixels the game draws. With the sharpest picture, every window point holds several pixels, so an in-game resolution opens a smaller window than its number suggests. The launcher passes the converted resolution to the game on every start."
	static let displayHandledInGame = "The game uses the display settings chosen inside Arknights."

	static func gameDraws(_ size: GameDisplaySize) -> String {
		"Game draws \(size.displayName)"
	}

	static func scalingDetail(_ scaling: GameDisplayPlan.Scaling) -> String {
		switch scaling {
		case .native: "Shown without scaling."
		case .metalFX: "MetalFX upscales it to fit your screen."
		case .stretched: "macOS stretches it to fit your screen, which looks softer."
		}
	}

	static let metalHUD = "Metal performance HUD"
	static let metalHUDDetail =
		"Shows the frame rate and graphics load over the game the next time it starts."
	static let gameMode = "Game Mode"
	static let gameModeDetail =
		"Asks macOS to give the game priority while it runs. Needs the free Xcode app from the App Store."
	static let gameModeHelp =
		"Uses Apple's gamepolicyctl tool, which ships only inside the full Xcode app, not the Command Line Tools."
	static let gameModeUnavailableDetail =
		"Not available on this Mac: Game Mode needs the free Xcode app from the App Store. Install it, then reopen Settings."
	static let wineSynchronization = "Wine synchronization"
	static let wineSynchronizationDetail =
		"How the game's background tasks wait for each other. MSYNC suits most Macs; try ESYNC if the game misbehaves. Applies on the next start."
	static let wineSynchronizationHelp =
		"Controls how Wine translates Windows thread waits. MSYNC uses macOS Mach synchronization and gave steadier frame pacing in our tests. ESYNC uses Wine's older event-based path and remains the compatibility fallback."

	static let appearanceTitle = "Appearance"
	static let appearanceSubtitle = "Artwork, colors, and icons"
	static let artworkPanel = "Artwork"
	static let artworkDetail = "The picture behind the launcher. You can also drop an image here."
	static let presets = "Presets…"
	static let colorsPanel = "Colors"
	static let dynamicTheme = "Match colors to the artwork"
	static let dynamicThemeDetail =
		"The launcher and the generated Dock icons borrow the artwork's colors."
	static let dynamicThemeHelp =
		"Dynamic Theme: derives the launcher accent, HUD tint, and generated Dock icon pair from the selected artwork."
	static let dockIconsPanel = "Dock icons"
	static let operatorIcons = "Operator"
	static let operatorIconsDetail =
		"Pick one operator for the launcher and game icons in your Dock."
	static let chooseOperator = "Choose Operator…"
	static let customIconOverrides = "Your own images"
	static let customIconOverridesDetail =
		"Use pictures from your Mac instead of the operator icons."
	static let launcher = "Launcher"
	static let launcherShowsPanel = "Launcher shows"
	static let showGameVersion = "Game version"
	static let showGameVersionDetail =
		"Shows the installed version and an update check above the Play button."
	static let serverTime = "Server time & reset countdown"
	static let serverTimeDetail = "Shows the server clock and the time until its next daily reset."

	static let audioTitle = "Audio"
	static let audioSubtitle = "Music while the launcher is open"
	static let audioMusic = "Music"
	static let audioBackgroundMusic = "Play background music"
	static let audioBackgroundMusicDetail =
		"Plays music while the launcher is open and the game is closed."
	static let audioURL = "Music URL"
	static let audioURLDetail = "A YouTube video or playlist link."
	static let audioURLPrompt = "https://www.youtube.com/playlist?..."
	static let audioVolume = "Volume"
	static let audioVolumeDetail = "How loud the launcher music plays."
	static let audioCurrentlyPlaying = "Show what's playing"
	static let audioCurrentlyPlayingDetail =
		"Shows the current track and playback controls on the launcher."

	static let updatesTitle = "Updates"
	static let updatesSubtitle = "Keep the launcher and the game up to date"
	static let automaticChecks = "Automatic Checks"
	static let announcements = "Announcements"
	static let announcementsDetail = "Show an occasional message from the project, once each."
	static let checking = "Checking…"
	static let updateAvailable = "Update available"

	static let installationTitle = "Installation"
	static let installationSubtitle = "Region, game files, and repairs"
	static let region = "Region"
	static let regionDetail = "Each region keeps its own game files and updates."
	static let location = "Location"
	static let status = "Status"
	static let statusDetail = "Whether the game is installed for this region."
	static let installationLocation = "Installation location"
	static let installationLocationDetail =
		"Move the game to a new folder, or point to a copy you already have."
	static let folder = "Folder"
	static let chooseNewLocation = "Choose New Location…"
	static let locateExisting = "Locate Existing Installation…"
	static let maintenance = "Maintenance"
	static let canaryFeatures = "Canary Features"
	static let canaryFeaturesDetail =
		"Try experimental features. Turning this off switches a Canary region back to Global."
	static let chinaClients = "Allow China regions"
	static let chinaClientsDetail = "Adds the China regions to the region list."
	static let taiwanClient = "Allow Taiwan region"
	static let taiwanClientDetail = "Adds the Taiwan region to the region list."
	static let repair = "Repair"
	static let repairAction = "Repair…"
	static let repairDetail =
		"Check the game files and download anything missing or damaged again."
	static let cacheGallery = "Preset Gallery Caches"
	static let logs = "Logs"
	static let showLogs = "Show Logs"
	static let showGameFilesHelp = "Show game files in Finder"
	static let setupAssistant = "Setup assistant"
	static let setupAssistantDetail = "Go through the first-run questions again."
	static let runAgain = "Run Setup Again…"
	static let wineSetup = "Environment setup"
	static let forceMigration = "Rebuild Environment"
	static let forceMigrationAction = "Rebuild…"
	static let forceMigrationConfirmation = "Rebuild the Game Environment?"
	static let forceMigrationDetail =
		"Sets up the game's Windows environment again the next time you start the game. Game files and saves are untouched; that start just takes longer."
	static let forceMigrationHelp =
		"Reruns Wine prefix initialization, DXMT installation, and registry overrides."
	static let resetSettings = "Reset Settings"
	static let resetSettingsAction = "Reset All Settings…"
	static let launcherSettings = "Launcher settings"
	static let resetSettingsConfirmation = "Reset All Launcher Settings?"
	static let resetSettingsDetail =
		"Puts every launcher setting back to its default. Game files, the install location, and the region are untouched."
	static let winePrefix = "Game Environment"
	static let winePrefixTitle = "Logins & environment"
	static let winePrefixDetail =
		"Deletes the game's Windows environment, including saved Yostar, Google, Apple, and Facebook logins. Game files are untouched; everything else is rebuilt on the next start."
	static let winePrefixHelp = "Deletes the Wine prefix folder shared by this publisher's regions."
	static let deleteWinePrefix = "Delete Environment…"
	static let deleteWinePrefixAction = "Delete Environment"
	static let deleteWinePrefixConfirmation = "Delete the Game Environment?"
	static let deleteWinePrefixDetail =
		"This signs you out of every login saved in the sign-in window. Game files are untouched."
	static let gameFiles = "Game files"
	static let gameFilesDetail = "Move the game for this region to the Trash."
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

	/// Tells players which in-game resolution produces the launcher's window size.
	static func inGameResolutionNote(window: GameDisplaySize, pixelsPerPoint: Int) -> String {
		"Resolutions inside Arknights count the pixels the game draws. With the sharpest picture, "
			+ "choose \(window.scaled(by: pixelsPerPoint).displayName) in the game for a "
			+ "\(window.displayName) window."
	}
}
