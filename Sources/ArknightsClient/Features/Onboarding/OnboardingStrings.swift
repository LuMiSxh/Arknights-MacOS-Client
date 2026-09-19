// SPDX-License-Identifier: MPL-2.0

enum OnboardingStrings {
	static let back = "Back"
	static let browsePresets = "Browse Presets…"
	static let checkAgain = "Check Again"
	static let checking = "Checking…"
	static let chooseImage = "Choose Image…"
	static let chooseOperator = "Choose Operator…"
	static let `continue` = "Continue"
	static let continueSetup = "Continue Setup"
	static let finishSetup = "Finish Setup"
	static let installAndContinue = "Install & Continue"
	static let installRosetta = "Install Rosetta 2…"
	static let reportProblem = "Report a Launcher Problem…"
	static let resumeAndContinue = "Resume & Continue"
	static let resumeDownload = "Resume Download"
	static let skipSetup = "Skip Setup"
	static let skipAnyway = "Skip Anyway"
	static let tryAgain = "Try Again"
	static let tryInstallationAgain = "Try Installation Again…"
	static let useDefault = "Use Default"
	static let useDefaults = "Use Defaults"

	static let extrasTitle = "Keep things current and comfortable"
	static let extrasSubtitle =
		"Automatic checks only look for new versions. Downloads still begin when you choose them, except for the installation already started by this setup."
	static let updatesTitle = "Updates & project notices"
	static let launcherUpdateTitle = "Check for Launcher Updates"
	static let launcherUpdateDetail =
		"Looks for a new launcher release when the app opens. You still choose when to download it."
	static let gameUpdateTitle = "Check for Game Updates"
	static let gameUpdateDetail =
		"Compares your installed files with Yostar's current version and offers Update when needed."
	static let announcementsTitle = "Show Project Announcements"
	static let announcementsDetail =
		"Shows important launcher notices, such as compatibility guidance, once per launch."
	static let musicTitle = "Launcher music"
	static let backgroundMusicTitle = "Play Background Music"
	static let backgroundMusicDetail =
		"Plays the configured YouTube music while the launcher is open and the game is not running."
	static let volume = "Volume"
	static let nowPlayingTitle = "Show Currently Playing"
	static let nowPlayingDetail =
		"Adds the current track and expandable playback controls to the main launcher."

	static let gameTitle = "Tune the game window"
	static let gameSubtitle =
		"These choices affect the next launch. Start conservatively on base-model Macs; you can raise resolution after confirming smooth gameplay."
	static let displaySettingsPanel = "Who controls display settings?"
	static let useGameDisplaySettings = "Use In-Game Display Settings"
	static let gameDisplaySettingsDetail =
		"Changes made inside Arknights remain in control after the first successful launch."
	static let launcherDisplaySettingsDetail =
		"The launcher overrides window mode and resolution every time the game starts."
	static let windowResolutionPanel = "Window & resolution"
	static let resolution = "Resolution"
	static let higherResolutionDetail =
		"Higher resolutions increase the work done by both Wine and the graphics translator."
	static let pixelDensityPanel = "Pixel density"
	static let highResolutionTitle = "High-Resolution Mode"
	static let highResolutionDetail =
		"Makes text sharper on Retina displays, but the larger backing surface can reduce performance. Turn it off first when the game feels uneven."
	static let runtimeOptimizations = "Runtime Optimizations"
	static let maximumFrameLatency = "Maximum Frame Latency"
	static let maximumFrameLatencyDetail =
		"Sets DXMT's maximum queued frames to 1–3. Lower values may reduce cursor latency but can make presentation less smooth. Applies on the next game launch."

	static let installationTitle = "Choose where you play"
	static let installationSubtitle =
		"Regions use separate game files and accounts. Pick the server you already use; you can install another region later from Settings."
	static let canaryFeatures = "Canary Features"
	static let canaryFeaturesDetail =
		"Enables experimental features and reveals separate permissions for Taiwan and China clients. Disabling it switches a selected Canary client to Global."
	static let chinaClients = "Allow China clients"
	static let chinaClientsDetail =
		"Allows selecting the China clients in addition to Canary features."
	static let taiwanClient = "Allow Taiwan client"
	static let taiwanClientDetail =
		"Allows selecting the Taiwan client in addition to Canary features."
	static let serverRegion = "Server region"
	static let officialClient = "Official PC client"
	static let downloadingTitle = "Downloading in the background"
	static let downloadingDetail = "You can continue setup while the game files download."
	static let existingTitle = "Existing installation found"
	static let partialTitle = "Paused download found"
	static let partialDetail = "The installer will continue from verified partial files."
	static let installDownloadDetail =
		"Selecting Install & Continue starts a resumable download. Closing the launcher pauses it safely."

	static let iconsTitle = "Choose your Dock icons"
	static let iconsSubtitle =
		"Choose an operator to create a Launcher icon with that character and a Game icon in the original Arknights style."
	static let dockIcons = "Dock icons"
	static let operatorIcons = "Operator Icons"
	static let operatorIconsDetail = "The same character is used for both Dock icons."
	static let customOverrides = "Custom Overrides"
	static let customOverridesDetail =
		"Optionally replace either generated icon with a local image."
	static let iconGame = "Game"
	static let iconLauncher = "Launcher"

	static let personalizationTitle = "Make the launcher yours"
	static let personalizationSubtitle =
		"Artwork fills the launcher window. Dynamic Theme samples that image and carries its color into controls and compatible icon styles."
	static let artwork = "Launcher artwork"
	static let currentArtworkAccessibility = "Current launcher artwork"
	static let themeStatusPanel = "Theme & launcher status"
	static let dynamicTheme = "Dynamic Theme"
	static let dynamicThemeDetail =
		"Matches the launcher accent, glass tint, and compatible icon styles to the selected artwork."
	static let gameVersion = "Show Game Version"
	static let gameVersionDetail =
		"Adds the installed Arknights version and a manual update check above the Play controls."
	static let resetCountdown = "Server Time & Reset Countdown"
	static let resetCountdownDetail =
		"Shows the active region and time remaining until that server's next daily reset."

	static let finishTitle = "Ready for deployment"
	static let finishSubtitle =
		"Your launcher settings are saved. You can change every choice again from Settings."
	static let communityTitle = "Community project"
	static let communityDetail =
		"Arknights Client is an unofficial community launcher. It is not affiliated with, endorsed by, or supported by Hypergryph or Yostar."
	static let issueDetail =
		"If the launcher, Wine runtime, or embedded browser misbehaves, please report it on GitHub with the generated diagnostics."
	static let communitySupport =
		"For account, payment, or game-service issues, contact Yostar support instead."
	static let contactSupport = "Contact Yostar Support…"
	static func communitySupport(region: GameRegion) -> String {
		if region.publisher == .gryphline {
			return
				"For account, payment, or game-service issues, contact Gryphline support instead."
		}
		if region.publisher == .hypergryph {
			return
				"For account, payment, or game-service issues, contact Hypergryph support instead."
		}
		return communitySupport
	}
	static func contactSupport(region: GameRegion) -> String {
		if region.publisher == .gryphline {
			return "Contact Gryphline Support…"
		}
		if region.publisher == .hypergryph {
			return "Contact Hypergryph Support…"
		}
		return contactSupport
	}
	static let finishStatusRunning = "Arknights is running"
	static let finishStatusDownloading = "Installation continues"
	static let finishStatusInstalled = "Arknights is ready"
	static let finishStatusPaused = "Installation is paused"
	static let finishGameActiveDetail = "Close the game with Command-Q before finishing setup."
	static let finishDownloadingDetail =
		"Finishing setup does not stop the download. The main launcher shows progress and enables Play when verification completes."
	static let finishInstalledDetail = "Finish setup to return to the launcher and start playing."
	static let finishPausedDetail =
		"Resume the download now or finish setup and continue later from the main launcher."

	static let rosettaIntroduction =
		"Rosetta 2 is missing. Install Apple’s compatibility layer so the bundled Wine runtime can start."
	static let rosettaInstalling = "Installing Rosetta 2 with Apple’s software update tool…"
	static let rosettaFailed = "Installation failed"
	static let rosettaManualInstall = "You can also install Rosetta manually in Terminal:"

	static let welcomeTitle = "Welcome to Arknights Client"
	static let welcomeSubtitle =
		"We’ll check the launcher first, then configure the game and the parts you see every day. Your choices apply immediately."
	static let launcherCurrent = "This launcher is current. Setup can continue."
	static let updateDetail =
		"Install the newer launcher and open it again. Setup stays pending so instructions always match the version you are using."
	static let updateCheckFailedDetail =
		"The launcher could not reach the update source. You can continue now; automatic checks will try again later."
	static let compatibilityPanel = "Intel compatibility"
	static let compatibilityWaiting =
		"Intel compatibility will be checked after the launcher update check."
	static let compatibilityChecking = "Checking whether the bundled Wine runtime can start…"
	static let compatibilityAvailable =
		"Compatibility verified. The bundled Wine runtime can start."
	static let compatibilityGameTestMode =
		"macOS Legacy Game Test Mode disables Rosetta, which the bundled Wine runtime requires. Disable the test mode, then restart your Mac:"
	static let compatibilityUnavailable =
		"macOS could not start an Intel test process. Restart your Mac, then check again. If the problem remains, include the launcher log in a bug report."
	static let compatibilityUnsupported =
		"This macOS version no longer provides the general Intel translation required by the bundled Wine runtime."
	static let skipSetupConfirmationTitle = "Skip setup?"
	static let skipSetupConfirmationDetail =
		"Setup reviews your client, display, Canary Features, and important launcher settings. You can run it again from Settings → General."

	static let setupAssistant = "SETUP ASSISTANT"

	static func versionAvailable(_ version: String) -> String {
		"Version \(version) is available."
	}
	static func installUpdate(_ version: String) -> String {
		"Install Update \(version)"
	}
	static func installationExisting(version: String, directory: String) -> String {
		"Arknights \(version) is ready in \(directory)."
	}
	static func readyToInstall(_ region: String) -> String {
		"Ready to install \(region)"
	}
	static func installationSize(_ size: String) -> String {
		"Download size after extraction: \(size)."
	}
	static func progressVersion(_ version: String) -> String {
		"Launcher v\(version)"
	}

	static func stepTitle(_ step: OnboardingStep) -> String {
		switch step {
		case .welcome: "System Check"
		case .installation: "Client & Installation"
		case .game: "Game"
		case .personalization: "Launcher"
		case .icons: "Icons"
		case .extras: "Updates & Audio"
		case .finish: "Ready"
		}
	}

	static func statusTitle(_ state: OnboardingUpdateState) -> String {
		switch state {
		case .checking: "Checking for launcher updates"
		case .current: "Ready for setup"
		case .updateRequired: "Update before setup"
		case .checkFailed: "Update check unavailable"
		}
	}

	static func displayMode(_ mode: GameDisplayMode) -> String {
		switch mode {
		case .fullscreen: "Fullscreen"
		case .windowed: "Windowed"
		case .borderlessWindow: "Borderless"
		}
	}

	static func regionDetail(_ region: GameRegion) -> String {
		switch region {
		case .global: "For the English Global client and Global Yostar accounts."
		case .japan: "For the Japanese client and Japan-region Yostar accounts."
		case .korea: "For the Korean client and Korea-region Yostar accounts."
		case .taiwan: "Taiwan (Canary)"
		case .china: "China (Canary)"
		case .chinaBilibili: "China — Bilibili (Canary)"
		}
	}

}
