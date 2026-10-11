// SPDX-License-Identifier: MPL-2.0

import ArknightsCore

/// Setup copy for players who are not technical: say what they will notice, keep numbers and
/// rendering terms out of titles, answers, and summaries, and put exact values in Settings.
enum OnboardingStrings {
	static let `continue` = "Continue"
	static let checkAgain = "Check Again"
	static let checking = "Checking…"

	// MARK: Welcome

	static func requiredSetupReason(schema: Int) -> String {
		switch schema {
		case 2:
			"Setup now asks a few simple questions about your screen, pointer, and look. Answer them once so the game fits your Mac."
		default:
			"The launcher changed how an important setting works. Go through each step once so everything keeps working."
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

	// MARK: Region

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

	// MARK: Display

	static func placementAnswer(
		_ answer: GamePlacementAnswer
	) -> OnboardingAnswer<
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
		case .branding:
			OnboardingAnswer(
				value: answer, title: "Branding",
				detail: "Shows the server logo in the top left corner.",
				systemImage: "textformat")
		}
	}

	// MARK: Updates & Audio

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

	// MARK: Ready

	static func communitySupport(region: GameRegion) -> String {
		if region.publisher == .gryphline {
			return
				"For account, payment, or game-service issues, contact Gryphline support instead."
		}
		if region.publisher == .hypergryph {
			return
				"For account, payment, or game-service issues, contact Hypergryph support instead."
		}
		return "For account, payment, or game-service issues, contact Yostar support instead."
	}

	static func contactSupport(region: GameRegion) -> String {
		if region.publisher == .gryphline {
			return "Contact Gryphline Support…"
		}
		if region.publisher == .hypergryph {
			return "Contact Hypergryph Support…"
		}
		return "Contact Yostar Support…"
	}

	// MARK: Rail

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
