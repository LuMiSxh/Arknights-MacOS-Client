// SPDX-License-Identifier: MPL-2.0

/// Setup copy for players who are not technical: say what they will notice, keep numbers and
/// rendering terms out of titles, answers, and summaries, and put exact values in Settings.
enum OnboardingStrings {
	static let back = "Back"
	static let `continue` = "Continue"
	static let continueSetup = "Continue Setup"
	static let checkAgain = "Check Again"
	static let checking = "Checking…"
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
	static let recommended = "Recommended"

	// MARK: Welcome

	static let welcomeTitle = "Welcome to Arknights Client"
	static let welcomeSubtitle =
		"First we'll check that everything is ready, then ask a few quick questions. Your answers apply right away."
	static let requiredWelcomeTitle = "Something important changed"
	static let requiredWelcomeSubtitle =
		"This version of the launcher needs you to go through setup once more. Your current settings are kept as the starting point."
	static let requiredSetupPanel = "Why setup is required"

	static func requiredSetupReason(schema: Int) -> String {
		switch schema {
		case 2:
			"Setup now asks a few simple questions about your screen, pointer, and look. Answer them once so the game fits your Mac."
		default:
			"The launcher changed how an important setting works. Go through each step once so everything keeps working."
		}
	}

	static let launcherCurrent = "This launcher is up to date. Setup can continue."
	static let updateDetail =
		"Install the newer launcher and open it again. Setup waits so its instructions match the version you use."
	static let updateCheckFailedDetail =
		"The launcher could not look for updates. You can continue now; it will try again later."
	static let compatibilityPanel = "Your Mac"
	static let compatibilityWaiting =
		"Your Mac is checked right after the launcher update check."
	static let compatibilityChecking = "Checking that your Mac can run the game…"
	static let compatibilityAvailable = "Your Mac can run the game."
	static let compatibilityGameTestMode =
		"On macOS 27 beta, Legacy Game Test Mode stops the game from running. Turn the test mode off, then restart your Mac:"
	static let compatibilityUnavailable =
		"The check could not finish. Restart your Mac, then check again. If it keeps failing, include the launcher log in a bug report."
	static let compatibilityUnsupported = "This version of macOS can no longer run the game."
	static let rosettaIntroduction =
		"Rosetta 2 is missing. Install Apple’s compatibility layer so the game can start."
	static let rosettaInstalling = "Installing Rosetta 2 with Apple’s software update tool…"
	static let rosettaFailed = "Installation failed"
	static let rosettaManualInstall = "You can also install Rosetta manually in Terminal:"
	static let skipSetupConfirmationTitle = "Skip setup?"
	static let skipSetupConfirmationDetail =
		"Setup picks your server, how the game looks on your screen, and how the launcher behaves. You can run it again from Settings → Installation."

	static func statusTitle(_ state: OnboardingUpdateState) -> String {
		switch state {
		case .checking: "Checking for launcher updates"
		case .current: "Ready for setup"
		case .updateRequired: "Update before setup"
		case .checkFailed: "Update check unavailable"
		}
	}

	static func versionAvailable(_ version: String) -> String {
		"Version \(version) is available."
	}

	static func installUpdate(_ version: String) -> String {
		"Install Update \(version)"
	}

	// MARK: Region

	static let regionTitle = "Your server"
	static let regionSubtitle =
		"Each server has its own game files and accounts. Pick the one you already play on; you can add another later in Settings."
	static let regionQuestion = "Which server do you play on?"
	static let canaryFeatures = "Canary Features"
	static let canaryFeaturesDetail =
		"Turns on experimental features and unlocks more servers. Turning it off switches a Canary server back to Global."
	static let chinaClients = "Allow China clients"
	static let chinaClientsDetail = "Lets you pick the China servers."
	static let taiwanClient = "Allow Taiwan client"
	static let taiwanClientDetail = "Lets you pick the Taiwan server."
	static let gameFiles = "Game files"
	static let existingTitle = "Game already installed"
	static let partialTitle = "Download paused"
	static let partialDetail = "Setup continues from where the download stopped."
	static let downloadingDetail = "You can keep going while the game downloads."
	static let verifyingDetail = "You can keep going while the game files are checked."
	static let installDownloadDetail =
		"Continue to start the download. Closing the launcher pauses it safely."

	static func regionAnswer(_ region: GameRegion) -> OnboardingAnswer<GameRegion> {
		let detail =
			switch region {
			case .global: "The English game, for Global accounts."
			case .japan: "The Japanese game, for Japan accounts."
			case .korea: "The Korean game, for Korea accounts."
			case .taiwan: "The Taiwan game, for Taiwan accounts."
			case .china: "The China game, for China accounts."
			case .chinaBilibili: "The China game, for Bilibili accounts."
			}
		return OnboardingAnswer(
			value: region, title: region.displayName, detail: detail, systemImage: "globe")
	}

	static func installationExisting(version: String, directory: String) -> String {
		"Arknights \(version) is ready in \(directory)."
	}

	static func readyToInstall(_ region: String) -> String {
		"Ready to install \(region)"
	}

	static func installationSize(_ size: String) -> String {
		"Needs about \(size) of space once installed."
	}

	// MARK: Display

	static let displayTitle = "How do you like to play?"
	static let displaySubtitle =
		"Your answers set the game up for this screen, so there is nothing to calculate."
	static let placementQuestion = "Where should the game appear?"

	static func placementAnswer(_ answer: GamePlacementAnswer) -> OnboardingAnswer<
		GamePlacementAnswer
	> {
		switch answer {
		case .window:
			OnboardingAnswer(
				value: answer, title: "In a window",
				detail: "Fits on your screen, so other apps stay within reach.",
				systemImage: "macwindow", isRecommended: true)
		case .fullscreen:
			OnboardingAnswer(
				value: answer, title: "Fullscreen",
				detail: "Fills the whole screen. Other apps stay hidden while you play.",
				systemImage: "arrow.up.left.and.arrow.down.right")
		}
	}

	static let windowSizeQuestion = "How big should the window be?"
	static let windowSizeFootnote = "You can pick an exact size in Settings any time."

	static func windowSizeAnswer(
		_ choice: GameWindowSizeChoice
	) -> OnboardingAnswer<GameWindowSizeChoice> {
		switch choice {
		case .fillScreen:
			OnboardingAnswer(
				value: choice, title: "Fill my screen",
				detail: "Uses all the room your screen has, like a maximized window.",
				systemImage: "rectangle.inset.filled", isRecommended: true)
		case .leaveRoom:
			OnboardingAnswer(
				value: choice, title: "Leave room for other apps",
				detail: "Smaller, so chat or a browser fits beside the game.",
				systemImage: "rectangle.split.2x1")
		}
	}

	static let renderingQuestion = "What matters most to you?"

	static func renderingAnswer(_ mode: GameRenderingMode) -> OnboardingAnswer<GameRenderingMode> {
		switch mode {
		case .retina:
			OnboardingAnswer(
				value: mode, title: "The sharpest picture",
				detail:
					"Uses every detail your screen has. Most Macs keep battles smooth this way.",
				systemImage: "sparkles", isRecommended: true, technicalName: "Retina")
		case .metalFX:
			OnboardingAnswer(
				value: mode, title: "Smooth play on big screens",
				detail: "Draws a lighter picture and sharpens it. Pick this if battles stutter.",
				systemImage: "gauge.with.dots.needle.67percent", technicalName: "MetalFX")
		case .lightweight:
			OnboardingAnswer(
				value: mode, title: "Longer battery life",
				detail: "Draws the lightest picture, so text looks a little softer.",
				systemImage: "leaf", technicalName: "Lightweight")
		}
	}

	static let pointerQuestion = "Which pointer should the game use?"

	static func pointerAnswer(_ answer: PointerAnswer) -> OnboardingAnswer<PointerAnswer> {
		switch answer {
		case .macPointer:
			OnboardingAnswer(
				value: answer, title: "Your Mac's pointer",
				detail: "Follows your mouse without delay. Applies the next time the game starts.",
				systemImage: "cursorarrow", isRecommended: true, technicalName: "Hardware cursor")
		case .gameCursor:
			OnboardingAnswer(
				value: answer, title: "Arknights' own cursor",
				detail: "The game's themed cursor, which can trail your mouse slightly.",
				systemImage: "scope", technicalName: "Software cursor")
		}
	}

	static func displaySummary(_ answers: GameDisplayAnswers) -> String {
		let placement =
			switch (answers.placement, answers.windowSize) {
			case (.window, .fillScreen): "The game opens in a window that fills your screen"
			case (.window, .leaveRoom): "The game opens in a window with room left for other apps"
			case (.fullscreen, _): "The game opens fullscreen"
			}
		let picture =
			switch answers.rendering {
			case .retina: "and looks as sharp as your screen allows."
			case .metalFX: "and favors smooth play on big screens."
			case .lightweight: "and goes easy on your battery."
			}
		return "\(placement) \(picture) You can change all of this in Settings → Game."
	}

	// MARK: Look

	static let lookTitle = "How should the launcher look?"
	static let lookSubtitle =
		"Pick the artwork, colors, and Dock icon. Every change shows up right away."
	static let artworkQuestion = "Which artwork should fill the launcher?"
	static let currentArtworkAccessibility = "Current launcher artwork"
	static let defaultArtwork = "Default artwork"
	static let defaultArtworkDetail = "The official artwork for your server."
	static let pickPreset = "Pick a preset…"
	static let pickPresetDetail = "Browse ready-made artwork."
	static let chooseOwnImage = "Choose my own image…"
	static let chooseOwnImageDetail = "Use any picture from your Mac."

	static let colorsQuestion = "Which colors should the launcher use?"

	static func colorsAnswer(_ matchesArtwork: Bool) -> OnboardingAnswer<Bool> {
		matchesArtwork
			? OnboardingAnswer(
				value: true, title: "Match the artwork",
				detail: "Buttons and glass pick up the colors of your artwork.",
				systemImage: "paintpalette", isRecommended: true)
			: OnboardingAnswer(
				value: false, title: "Keep it neutral",
				detail: "Uses the standard launcher colors whatever the artwork.",
				systemImage: "circle.lefthalf.filled")
	}

	static let dockQuestion = "Which operator should your Dock show?"
	static let dockLauncherIcon = "Launcher"
	static let dockGameIcon = "Game"
	static let chooseOperator = "Choose Operator…"
	static let chooseOperatorDetail = "Gives the launcher and the game a matching Dock icon."
	static let standardIcons = "Use the standard icons"
	static let standardIconsDetail = "Go back to the icons the launcher and the game came with."
	static let infoQuestion = "What should the launcher show?"

	static func infoAnswer(_ answer: LauncherInfoAnswer) -> OnboardingAnswer<LauncherInfoAnswer> {
		switch answer {
		case .gameVersion:
			OnboardingAnswer(
				value: answer, title: "Game version",
				detail: "Shows the installed version above Play, with a quick update check.",
				systemImage: "number.square")
		case .serverTime:
			OnboardingAnswer(
				value: answer, title: "Server time & reset countdown",
				detail: "Shows how long until your server's next daily reset.",
				systemImage: "clock")
		}
	}

	// MARK: Updates & Audio

	static let extrasTitle = "A few last questions"
	static let extrasSubtitle =
		"Looking for updates never downloads anything by itself, apart from the game files you chose to install."
	static let updatesQuestion = "How should the launcher stay up to date?"

	static func updateAnswer(_ answer: UpdateCheckAnswer) -> OnboardingAnswer<UpdateCheckAnswer> {
		switch answer {
		case .automatic:
			OnboardingAnswer(
				value: answer, title: "Check automatically",
				detail:
					"Looks for new versions and project notices when the app opens. You choose when to download.",
				systemImage: "checkmark.arrow.trianglehead.counterclockwise", isRecommended: true)
		case .noticesOnly:
			OnboardingAnswer(
				value: answer, title: "Only show important notices",
				detail:
					"Skips version checks but still tells you when a game update needs a newer launcher.",
				systemImage: "megaphone")
		case .manual:
			OnboardingAnswer(
				value: answer, title: "I'll check myself",
				detail: "Never looks on its own. You can turn checks on later in Settings.",
				systemImage: "hand.raised")
		}
	}

	static let musicQuestion = "Play music while the launcher is open?"

	static func musicAnswer(_ plays: Bool) -> OnboardingAnswer<Bool> {
		plays
			? OnboardingAnswer(
				value: true, title: "Yes, play music",
				detail: "Plays the launcher's YouTube music and pauses while the game runs.",
				systemImage: "music.note")
			: OnboardingAnswer(
				value: false, title: "No, keep it quiet",
				detail: "You can turn music on later in Settings.",
				systemImage: "speaker.slash")
	}

	static let musicTitle = "Music"
	static let volume = "Volume"
	static let nowPlayingTitle = "Show what's playing"
	static let nowPlayingDetail = "Adds the current track and playback controls to the launcher."

	// MARK: Ready

	static let finishTitle = "Ready for deployment"
	static let finishSubtitle = "Your choices are saved. You can change any of them in Settings."
	static let communityTitle = "Community project"
	static let communityDetail =
		"Arknights Client is an unofficial community launcher. It is not affiliated with, endorsed by, or supported by Hypergryph or Yostar."
	static let issueDetail =
		"If the launcher, the game start, or the sign-in window misbehaves, please report it on GitHub. The report fills in the technical details for you."
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
	static let finishStatusDownloading = "The download continues"
	static let finishStatusInstalled = "Arknights is ready"
	static let finishStatusPaused = "The download is paused"
	static let finishGameActiveDetail = "Close the game with Command-Q before finishing setup."
	static let finishDownloadingDetail =
		"Finishing setup does not stop the download. The launcher shows its progress and unlocks Play when it is done."
	static let finishInstalledDetail = "Finish setup to return to the launcher and start playing."
	static let finishPausedDetail =
		"Resume the download now, or finish setup and continue later from the launcher."

	// MARK: Rail

	static let setupAssistant = "SETUP ASSISTANT"

	static func progressVersion(_ version: String) -> String {
		"Launcher v\(version)"
	}

	static func stepTitle(_ step: OnboardingStep) -> String {
		switch step {
		case .welcome: "System Check"
		case .region: "Region"
		case .display: "Display"
		case .look: "Look"
		case .extras: "Updates & Audio"
		case .finish: "Ready"
		}
	}
}
