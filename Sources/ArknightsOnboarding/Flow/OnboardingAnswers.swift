// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore

nonisolated enum GamePlacementAnswer: CaseIterable, Sendable {
	case fullscreen
	case window
}

// The setup assistant's display questions. Every answer lets the launcher size the game for
// the current screen, so players never have to calculate resolutions.
nonisolated struct GameDisplayAnswers: Equatable, Sendable {
	var placement: GamePlacementAnswer
	var windowSize: WindowSizeAnswer
	var rendering: GameRenderingMode
	var frameRateLimit: GameFrameRateLimit

	static let recommended = GameDisplayAnswers(
		placement: .fullscreen, rendering: .retina,
		frameRateLimit: GameLaunchOptions.default.frameRateLimit)

	init(
		placement: GamePlacementAnswer, windowSize: WindowSizeAnswer = .preset(.fillScreen),
		rendering: GameRenderingMode,
		frameRateLimit: GameFrameRateLimit = GameLaunchOptions.default.frameRateLimit
	) {
		self.placement = placement
		self.windowSize = windowSize
		self.rendering = rendering
		self.frameRateLimit = frameRateLimit
	}

	// Reads the answers back from saved options, so returning to setup shows earlier choices.
	init(_ options: GameLaunchOptions, screen: GameScreenMetrics?) {
		placement = options.displayMode == .fullscreen ? .fullscreen : .window
		windowSize = WindowSizeAnswer(options.windowSize, on: screen)
		rendering = options.renderingMode
		frameRateLimit = options.frameRateLimit
	}

	// The window-size answers to offer: every preset, plus the current size when it is custom.
	var offeredWindowSizes: [WindowSizeAnswer] {
		let presets = GameWindowSizeChoice.allCases.map(WindowSizeAnswer.preset)
		guard case .custom = windowSize else { return presets }
		return presets + [windowSize]
	}

	// Applies the answers and keeps every unrelated launch option.
	func applied(to base: GameLaunchOptions, screen: GameScreenMetrics) -> GameLaunchOptions {
		var options = base
		options.usesGameSettings = false
		options.renderingMode = rendering
		options.frameRateLimit = frameRateLimit
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

nonisolated enum PointerAnswer: CaseIterable, Sendable {
	case gameCursor
	case macPointer

	static let recommended = PointerAnswer.gameCursor

	var usesHardwareCursor: Bool { self == .macPointer }

	init(usesHardwareCursor: Bool) {
		self = usesHardwareCursor ? .macPointer : .gameCursor
	}
}

extension PointerAnswer {
	var answer: OnboardingAnswer<PointerAnswer> {
		switch self {
		case .gameCursor:
			OnboardingAnswer(
				value: self, title: "Game cursor", detail: "Themed. May lag slightly.",
				systemImage: "scope", isRecommended: true, help: "Software cursor")
		case .macPointer:
			OnboardingAnswer(
				value: self, title: "macOS cursor", detail: "No input lag. Applies on next launch.",
				systemImage: "cursorarrow", help: "Hardware cursor")
		}
	}
}

extension LauncherPreferencesController {
	var pointerAnswer: PointerAnswer {
		get { PointerAnswer(usesHardwareCursor: usesHardwareCursor) }
		set { usesHardwareCursor = newValue.usesHardwareCursor }
	}
}

// Appearance applies the moment it is picked, so setup switches to the chosen look at once.
extension LauncherAppearance {
	var answer: OnboardingAnswer<LauncherAppearance> {
		switch self {
		case .system:
			OnboardingAnswer(
				value: self, title: "System", detail: "Matches your Mac’s appearance.",
				systemImage: "circle.lefthalf.filled", isRecommended: true)
		case .light:
			OnboardingAnswer(
				value: self, title: "Light", detail: "Always uses light surfaces.",
				systemImage: "sun.max")
		case .dark:
			OnboardingAnswer(
				value: self, title: "Dark", detail: "Always uses dark surfaces.",
				systemImage: "moon")
		}
	}
}

// Shared by Home controls and Branding, which use the same three tones.
extension HomeTheme {
	var answer: OnboardingAnswer<HomeTheme> {
		switch self {
		case .automatic:
			OnboardingAnswer(
				value: self, title: "Automatic",
				detail: "Light over bright artwork, dark over dark artwork.",
				systemImage: "wand.and.stars", isRecommended: true)
		case .dark:
			OnboardingAnswer(
				value: self, title: "Dark", detail: "Always dark, whatever the artwork.",
				systemImage: "moon")
		case .light:
			OnboardingAnswer(
				value: self, title: "Light", detail: "Always light, whatever the artwork.",
				systemImage: "sun.max")
		}
	}

	// Branding follows the Home controls tone when it is Automatic.
	var brandingAnswer: OnboardingAnswer<HomeTheme> {
		var answer = answer
		if self == .automatic { answer.detail = "Uses the same tone as the Home controls." }
		return answer
	}
}

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
				detail: "Shows how long until your server’s next daily reset.",
				systemImage: "clock")
		case .branding:
			OnboardingAnswer(
				value: self, title: "Show branding",
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

nonisolated enum UpdateCheckAnswer: CaseIterable, Sendable {
	case automatic
	case noticesOnly
	case manual

	static let recommended = UpdateCheckAnswer.automatic

	var checksForUpdates: Bool { self == .automatic }
	var showsAnnouncements: Bool { self != .manual }

	// The answer the saved preferences match, or nil when they were customized in Settings.
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
				value: self, title: "Automatic",
				systemImage: "checkmark.arrow.trianglehead.counterclockwise", isRecommended: true)
		case .noticesOnly:
			OnboardingAnswer(
				value: self, title: "Notices only", detail: "Project news. No version checks.",
				systemImage: "megaphone")
		case .manual:
			OnboardingAnswer(
				value: self, title: "Manual", detail: "No automatic checks.",
				systemImage: "hand.raised")
		}
	}
}

nonisolated enum DiscordPresenceAnswer: CaseIterable, Sendable {
	case off
	case on

	static let recommended = DiscordPresenceAnswer.off

	var showsDiscordPresence: Bool { self == .on }
}

extension DiscordPresenceAnswer {
	var answer: OnboardingAnswer<DiscordPresenceAnswer> {
		switch self {
		case .off:
			OnboardingAnswer(
				value: self, title: "Off", detail: "Nothing is shared with Discord.",
				systemImage: "xmark.circle", isRecommended: true)
		case .on:
			OnboardingAnswer(
				value: self, title: "Show on Discord",
				detail:
					"Shares the game name, your server, and the session time.",
				systemImage: "gamecontroller")
		}
	}
}

extension LauncherPreferencesController {
	var discordPresenceAnswer: DiscordPresenceAnswer {
		get { showsDiscordPresence ? .on : .off }
		set { showsDiscordPresence = newValue.showsDiscordPresence }
	}
}

extension GamePlacementAnswer {
	var answer: OnboardingAnswer<GamePlacementAnswer> {
		switch self {
		case .fullscreen:
			OnboardingAnswer(
				value: self, title: "Fullscreen", detail: "Uses the whole display.",
				systemImage: "arrow.up.left.and.arrow.down.right", isRecommended: true)
		case .window:
			OnboardingAnswer(
				value: self, title: "Windowed", detail: "Resizable window beside other apps.",
				systemImage: "macwindow")
		}
	}
}

// A preset, or a custom size set in Settings that matches no preset. Setup keeps a custom size
// unless the player picks a preset.
nonisolated enum WindowSizeAnswer: Hashable, Sendable {
	case preset(GameWindowSizeChoice)
	case custom(GameDisplaySize)

	init(_ size: GameDisplaySize, on screen: GameScreenMetrics?) {
		let preset = screen.flatMap { GameWindowSizeChoice.matching(size, on: $0) }
		self = preset.map { Self.preset($0) } ?? .custom(size)
	}

	func size(on screen: GameScreenMetrics) -> GameDisplaySize {
		switch self {
		case .preset(let choice): choice.size(on: screen)
		case .custom(let size): size
		}
	}
}

extension WindowSizeAnswer {
	// The title shows the window size on `screen`, for example "Compact · 1600 × 900".
	func answer(on screen: GameScreenMetrics?) -> OnboardingAnswer<WindowSizeAnswer> {
		return switch self {
		case .preset(.fillScreen):
			OnboardingAnswer(
				value: self, title: "Fill screen",
				systemImage: "rectangle.inset.filled", isRecommended: true)
		case .preset(.leaveRoom):
			OnboardingAnswer(
				value: self,
				title: "Compact" + (screen.map { " · \(size(on: $0).displayName)" } ?? ""),
				systemImage: "rectangle.split.2x1")
		case .custom(let size):
			OnboardingAnswer(
				value: self, title: "Custom · \(size.displayName)",
				systemImage: "slider.horizontal.3")
		}
	}
}

extension GameRenderingMode {
	var answer: OnboardingAnswer<GameRenderingMode> {
		switch self {
		case .retina:
			OnboardingAnswer(
				value: self, title: "Retina", detail: "Full display resolution. Sharpest.",
				systemImage: "sparkles", isRecommended: true)
		case .metalFX:
			OnboardingAnswer(
				value: self, title: "MetalFX",
				detail: "Renders at 1× and upscales with MetalFX. Use it if the frame rate drops.",
				systemImage: "gauge.with.dots.needle.67percent")
		case .standard:
			OnboardingAnswer(
				value: self, title: "Standard",
				detail: "Renders at 1× and macOS scales the window. Softer image, lowest GPU load.",
				systemImage: "rectangle.dashed")
		}
	}
}

extension GameFrameRateLimit {
	var answer: OnboardingAnswer<GameFrameRateLimit> {
		OnboardingAnswer(
			value: self, title: displayName, systemImage: "speedometer",
			isRecommended: self == .fps120)
	}
}
