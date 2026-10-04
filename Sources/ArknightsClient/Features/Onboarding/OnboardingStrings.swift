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

	static let extrasTitle = "A few last questions"
	static let extrasSubtitle =
		"Automatic checks only look for new versions. Downloads still begin when you choose them, except for the installation already started by this setup."
	static let updatesQuestion = "How should the launcher stay up to date?"

	static func updateAnswer(_ answer: UpdateCheckAnswer) -> OnboardingAnswer<UpdateCheckAnswer> {
		switch answer {
		case .automatic:
			OnboardingAnswer(
				value: answer, title: "Check automatically",
				detail:
					"Looks for new launcher and game versions when the app opens, and shows important project notices. You still choose when to download.",
				systemImage: "checkmark.arrow.trianglehead.counterclockwise", isRecommended: true)
		case .noticesOnly:
			OnboardingAnswer(
				value: answer, title: "Only show important notices",
				detail:
					"Skips version checks but still shows compatibility notices, such as when a game update needs a newer launcher.",
				systemImage: "megaphone")
		case .manual:
			OnboardingAnswer(
				value: answer, title: "I'll check myself",
				detail:
					"Never looks for new versions or notices on its own. You can turn checks on later in Settings.",
				systemImage: "hand.raised")
		}
	}

	static let musicQuestion = "Play music while the launcher is open?"

	static func musicAnswer(_ plays: Bool) -> OnboardingAnswer<Bool> {
		plays
			? OnboardingAnswer(
				value: true, title: "Yes, play music",
				detail: "Plays the configured YouTube music and stops while the game is running.",
				systemImage: "music.note")
			: OnboardingAnswer(
				value: false, title: "No, keep it quiet",
				detail: "You can turn music on later in Settings.",
				systemImage: "speaker.slash")
	}

	static let musicTitle = "Music"
	static let volume = "Volume"
	static let recommended = "Recommended"
	static let nowPlayingTitle = "Show Currently Playing"
	static let nowPlayingDetail =
		"Adds the current track and expandable playback controls to the main launcher."

	static let gameTitle = "How do you like to play?"
	static let gameSubtitle =
		"Your answers set up the game for this screen. The launcher picks the window size and resolution, so the picture stays sharp without any math."
	static let placementQuestion = "Where should the game appear?"

	static func placementAnswer(_ answer: GamePlacementAnswer) -> OnboardingAnswer<
		GamePlacementAnswer
	> {
		switch answer {
		case .window:
			OnboardingAnswer(
				value: answer, title: "In a window",
				detail: "Sized to fit your screen, so other apps stay within reach.",
				systemImage: "macwindow", isRecommended: true)
		case .fullscreen:
			OnboardingAnswer(
				value: answer, title: "Fullscreen",
				detail:
					"Fills the whole screen. Often the smoothest, but other apps stay hidden while you play.",
				systemImage: "arrow.up.left.and.arrow.down.right")
		}
	}

	static let renderingQuestion = "What matters most to you?"

	static func renderingAnswer(_ mode: GameRenderingMode) -> OnboardingAnswer<GameRenderingMode> {
		switch mode {
		case .retina:
			OnboardingAnswer(
				value: mode, title: "The sharpest picture",
				detail: "Uses every pixel of your display. Most Macs keep battles smooth this way.",
				systemImage: "sparkles", isRecommended: true)
		case .metalFX:
			OnboardingAnswer(
				value: mode, title: "Smooth play on large screens",
				detail:
					"Draws fewer pixels and sharpens them with MetalFX. Choose it for 4K displays or if battles stutter.",
				systemImage: "gauge.with.dots.needle.67percent")
		case .lightweight:
			OnboardingAnswer(
				value: mode, title: "Less heat and battery use",
				detail: "Draws the fewest pixels, so text looks a little softer.",
				systemImage: "leaf")
		}
	}

	static let displaySummaryFallback =
		"Arknights' own settings currently decide the game size. Pick an answer to let the launcher size it instead."

	static func displaySummary(render: String) -> String {
		render + " You can fine-tune this later in Settings → General."
	}

	static let runtimeOptimizations = "Runtime Optimizations"
	static let maximumFrameLatency = "Maximum Frame Latency"
	static let maximumFrameLatencyDetail =
		"Lower values can make the cursor feel more responsive, but may lower or unsettle the frame rate. Applies on the next game launch."

	static let installationTitle = "Which server do you play on?"
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
	static let downloadingDetail = "You can continue setup while the game files download."
	static let verifyingDetail = "You can continue setup while the existing game files are checked."
	static let existingTitle = "Existing installation found"
	static let partialTitle = "Paused download found"
	static let partialDetail = "The installer will continue from verified partial files."
	static let installDownloadDetail =
		"Selecting Install & Continue starts a resumable download. Closing the launcher pauses it safely."

	static let iconsTitle = "Which operator should your Dock show?"
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

	static let personalizationTitle = "How should the launcher look?"
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
		"If the launcher, the game start, or the sign-in window misbehaves, please report it on GitHub. The report includes diagnostic details automatically."
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
		"Rosetta 2 is missing. Install Apple’s compatibility layer so the game can start."
	static let rosettaInstalling = "Installing Rosetta 2 with Apple’s software update tool…"
	static let rosettaFailed = "Installation failed"
	static let rosettaManualInstall = "You can also install Rosetta manually in Terminal:"

	static let welcomeTitle = "Welcome to Arknights Client"
	static let welcomeSubtitle =
		"We’ll check the launcher first, then ask a few questions to set up the game and the parts you see every day. Your answers apply immediately."
	static let requiredWelcomeTitle = "Something important changed"
	static let requiredWelcomeSubtitle =
		"This launcher version needs you to go through setup once more before you continue. Your existing settings are kept as the starting point."
	static let requiredSetupPanel = "Why setup is required"

	static func requiredSetupReason(schema: Int) -> String {
		switch schema {
		case 2:
			"Display settings are now set up through a few questions. Answer them once so the launcher can size the game for your screen."
		default:
			"The launcher changed how important settings work. Review each step once so everything keeps working as expected."
		}
	}
	static let launcherCurrent = "This launcher is current. Setup can continue."
	static let updateDetail =
		"Install the newer launcher and open it again. Setup stays pending so instructions always match the version you are using."
	static let updateCheckFailedDetail =
		"The launcher could not reach the update source. You can continue now; automatic checks will try again later."
	static let compatibilityPanel = "Intel compatibility"
	static let compatibilityWaiting =
		"Intel compatibility will be checked after the launcher update check."
	static let compatibilityChecking = "Checking whether this Mac can run the game…"
	static let compatibilityAvailable =
		"Compatibility verified. The bundled Wine runtime can start."
	static let compatibilityGameTestMode =
		"On macOS 27 beta, Legacy Game Test Mode disables Rosetta, which the game needs. Disable the test mode, then restart your Mac:"
	static let compatibilityUnavailable =
		"macOS could not start an Intel test process. Restart your Mac, then check again. If the problem remains, include the launcher log in a bug report."
	static let compatibilityUnsupported =
		"This macOS version no longer provides the general Intel translation required to run the game."
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
