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
	var windowSize: GameWindowSizeChoice
	var rendering: GameRenderingMode
	var frameRateLimit: GameFrameRateLimit

	static let recommended = GameDisplayAnswers(
		placement: .fullscreen, rendering: .retina, frameRateLimit: .unlimited)

	init(
		placement: GamePlacementAnswer, windowSize: GameWindowSizeChoice = .fillScreen,
		rendering: GameRenderingMode, frameRateLimit: GameFrameRateLimit = .unlimited
	) {
		self.placement = placement
		self.windowSize = windowSize
		self.rendering = rendering
		self.frameRateLimit = frameRateLimit
	}

	// Reads the answers back from saved options, so returning to setup shows earlier choices.
	// A window size set by hand in Settings reads back as filling the screen.
	init(_ options: GameLaunchOptions, screen: GameScreenMetrics?) {
		placement = options.displayMode == .fullscreen ? .fullscreen : .window
		windowSize =
			screen.flatMap { GameWindowSizeChoice.matching(options.windowSize, on: $0) }
			?? .fillScreen
		rendering = options.renderingMode
		frameRateLimit = options.frameRateLimit
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

extension GameWindowSizeChoice {
	// The title shows the window size on `screen`, for example "Compact · 1600 × 900".
	func answer(on screen: GameScreenMetrics?) -> OnboardingAnswer<GameWindowSizeChoice> {
		return switch self {
		case .fillScreen:
			OnboardingAnswer(
				value: self, title: "Fill screen",
				systemImage: "rectangle.inset.filled", isRecommended: true)
		case .leaveRoom:
			OnboardingAnswer(
				value: self,
				title: "Compact" + (screen.map { " · \(size(on: $0).displayName)" } ?? ""),
				systemImage: "rectangle.split.2x1")
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
			isRecommended: self == .unlimited)
	}
}
