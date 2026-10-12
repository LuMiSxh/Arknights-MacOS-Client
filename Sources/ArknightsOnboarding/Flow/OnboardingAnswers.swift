// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore

/// Where the game appears, answered during setup.
nonisolated enum GamePlacementAnswer: CaseIterable, Sendable {
	case window
	case fullscreen
}

/// The setup assistant's display questions. Every answer lets the launcher size the game for
/// the current screen, so players never have to calculate resolutions.
nonisolated struct GameDisplayAnswers: Equatable, Sendable {
	var placement: GamePlacementAnswer
	var windowSize: GameWindowSizeChoice
	var rendering: GameRenderingMode

	static let recommended = GameDisplayAnswers(placement: .window, rendering: .retina)

	init(
		placement: GamePlacementAnswer, windowSize: GameWindowSizeChoice = .fillScreen,
		rendering: GameRenderingMode
	) {
		self.placement = placement
		self.windowSize = windowSize
		self.rendering = rendering
	}

	/// Reads the answers back from saved options, so returning to setup shows earlier choices.
	/// A window size set by hand in Settings reads back as filling the screen.
	init(_ options: GameLaunchOptions, screen: GameScreenMetrics?) {
		placement = options.displayMode == .fullscreen ? .fullscreen : .window
		windowSize =
			screen.flatMap { GameWindowSizeChoice.matching(options.windowSize, on: $0) }
			?? .fillScreen
		rendering = options.renderingMode
	}

	/// Applies the answers and keeps every unrelated launch option.
	func applied(to base: GameLaunchOptions, screen: GameScreenMetrics) -> GameLaunchOptions {
		var options = base
		options.usesGameSettings = false
		options.renderingMode = rendering
		switch placement {
		case .window:
			options.displayMode = .windowed
			options.windowSize = windowSize.size(on: screen)
		case .fullscreen:
			// Native is pixel-exact on every display; the official resolution stays as the
			// fallback for older launchers.
			options.displayMode = .fullscreen
			options.fullscreenResolution = .native
			options.resolution = screen.fullscreenResolution
		}
		return options
	}
}

/// Which pointer the game shows, answered during setup.
nonisolated enum PointerAnswer: CaseIterable, Sendable {
	case macPointer
	case gameCursor

	static let recommended = PointerAnswer.macPointer

	var usesHardwareCursor: Bool { self == .macPointer }

	init(usesHardwareCursor: Bool) {
		self = usesHardwareCursor ? .macPointer : .gameCursor
	}
}

extension PointerAnswer {
	var answer: OnboardingAnswer<PointerAnswer> {
		switch self {
		case .macPointer:
			OnboardingAnswer(
				value: self, title: "Your Mac's pointer",
				detail: "Follows your mouse without delay. Applies the next time the game starts.",
				systemImage: "cursorarrow", isRecommended: true, technicalName: "Hardware cursor")
		case .gameCursor:
			OnboardingAnswer(
				value: self, title: "Arknights' own cursor",
				detail: "The game's themed cursor, which can trail your mouse slightly.",
				systemImage: "scope", technicalName: "Software cursor")
		}
	}
}

extension LauncherPreferencesController {
	var pointerAnswer: PointerAnswer {
		get { PointerAnswer(usesHardwareCursor: usesHardwareCursor) }
		set { usesHardwareCursor = newValue.usesHardwareCursor }
	}
}

/// What the launcher shows around the Play button, answered during setup.
nonisolated enum LauncherInfoAnswer: CaseIterable, Hashable, Sendable {
	case gameVersion
	case serverTime
	case branding
}

extension LauncherInfoAnswer {
	var answer: OnboardingAnswer<LauncherInfoAnswer> {
		switch self {
		case .gameVersion:
			OnboardingAnswer(
				value: self, title: "Game version",
				detail: "Shows the installed version above Play, with a quick update check.",
				systemImage: "number.square")
		case .serverTime:
			OnboardingAnswer(
				value: self, title: "Server time & reset countdown",
				detail: "Shows how long until your server's next daily reset.",
				systemImage: "clock")
		case .branding:
			OnboardingAnswer(
				value: self, title: "Branding",
				detail: "Shows the server logo in the top left corner.",
				systemImage: "textformat")
		}
	}
}

extension LauncherPreferencesController {
	var shownLauncherInfo: Set<LauncherInfoAnswer> {
		get {
			var shown = Set<LauncherInfoAnswer>()
			if showsGameVersion { shown.insert(.gameVersion) }
			if showsServerResetCountdown { shown.insert(.serverTime) }
			if showsBranding { shown.insert(.branding) }
			return shown
		}
		set {
			showsGameVersion = newValue.contains(.gameVersion)
			showsServerResetCountdown = newValue.contains(.serverTime)
			showsBranding = newValue.contains(.branding)
		}
	}
}

/// How the launcher keeps up with new versions and project notices, answered during setup.
nonisolated enum UpdateCheckAnswer: CaseIterable, Sendable {
	case automatic
	case noticesOnly
	case manual

	static let recommended = UpdateCheckAnswer.automatic

	var checksForUpdates: Bool { self == .automatic }
	var showsAnnouncements: Bool { self != .manual }

	/// The answer the saved preferences match, or nil when they were customized in Settings.
	init?(launcherChecks: Bool, gameChecks: Bool, announcements: Bool) {
		guard
			let answer = Self.allCases.first(where: {
				$0.checksForUpdates == launcherChecks && $0.checksForUpdates == gameChecks
					&& $0.showsAnnouncements == announcements
			})
		else { return nil }
		self = answer
	}
}

extension UpdateCheckAnswer {
	var answer: OnboardingAnswer<UpdateCheckAnswer> {
		switch self {
		case .automatic:
			OnboardingAnswer(
				value: self, title: "Check automatically",
				detail:
					"Looks for new versions and project notices when the app opens. You choose when to download.",
				systemImage: "checkmark.arrow.trianglehead.counterclockwise", isRecommended: true)
		case .noticesOnly:
			OnboardingAnswer(
				value: self, title: "Only show important notices",
				detail:
					"Skips version checks but still tells you when a game update needs a newer launcher.",
				systemImage: "megaphone")
		case .manual:
			OnboardingAnswer(
				value: self, title: "I'll check myself",
				detail: "Never looks on its own. You can turn checks on later in Settings.",
				systemImage: "hand.raised")
		}
	}
}

extension GamePlacementAnswer {
	var answer: OnboardingAnswer<GamePlacementAnswer> {
		switch self {
		case .window:
			OnboardingAnswer(
				value: self, title: "In a window",
				detail: "Fits on your screen, so other apps stay within reach.",
				systemImage: "macwindow", isRecommended: true)
		case .fullscreen:
			OnboardingAnswer(
				value: self, title: "Fullscreen",
				detail: "Fills the whole screen. Other apps stay hidden while you play.",
				systemImage: "arrow.up.left.and.arrow.down.right")
		}
	}
}

extension GameWindowSizeChoice {
	var answer: OnboardingAnswer<GameWindowSizeChoice> {
		switch self {
		case .fillScreen:
			OnboardingAnswer(
				value: self, title: "Fill my screen",
				detail: "Uses all the room your screen has, like a maximized window.",
				systemImage: "rectangle.inset.filled", isRecommended: true)
		case .leaveRoom:
			OnboardingAnswer(
				value: self, title: "Leave room for other apps",
				detail: "Smaller, so chat or a browser fits beside the game.",
				systemImage: "rectangle.split.2x1")
		}
	}
}

extension GameRenderingMode {
	var answer: OnboardingAnswer<GameRenderingMode> {
		switch self {
		case .retina:
			OnboardingAnswer(
				value: self, title: "The sharpest picture",
				detail:
					"Uses every detail your screen has. Most Macs keep battles smooth this way.",
				systemImage: "sparkles", isRecommended: true, technicalName: "Retina")
		case .metalFX:
			OnboardingAnswer(
				value: self, title: "Smooth play on big screens",
				detail: "Draws a lighter picture and sharpens it. Pick this if battles stutter.",
				systemImage: "gauge.with.dots.needle.67percent", technicalName: "MetalFX")
		case .lightweight:
			OnboardingAnswer(
				value: self, title: "Longer battery life",
				detail: "Draws the lightest picture, so text looks a little softer.",
				systemImage: "leaf", technicalName: "Lightweight")
		}
	}
}
