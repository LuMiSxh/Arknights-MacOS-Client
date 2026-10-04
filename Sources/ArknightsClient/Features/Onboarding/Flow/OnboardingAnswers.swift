// SPDX-License-Identifier: MPL-2.0

import AppKit

/// Where the game appears, answered during setup.
enum GamePlacementAnswer: CaseIterable, Sendable {
	case window
	case fullscreen
}

/// The setup assistant's display questions. Every answer lets the launcher size the game for
/// the current screen, so players never have to calculate resolutions.
struct GameDisplayAnswers: Equatable, Sendable {
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
enum PointerAnswer: CaseIterable, Sendable {
	case macPointer
	case gameCursor

	static let recommended = PointerAnswer.macPointer

	var usesHardwareCursor: Bool { self == .macPointer }

	init(usesHardwareCursor: Bool) {
		self = usesHardwareCursor ? .macPointer : .gameCursor
	}
}

extension LauncherPreferencesController {
	var pointerAnswer: PointerAnswer {
		get { PointerAnswer(usesHardwareCursor: usesHardwareCursor) }
		set { usesHardwareCursor = newValue.usesHardwareCursor }
	}
}

/// What the launcher shows around the Play button, answered during setup.
enum LauncherInfoAnswer: CaseIterable, Hashable, Sendable {
	case gameVersion
	case serverTime
}

extension LauncherPreferencesController {
	var shownLauncherInfo: Set<LauncherInfoAnswer> {
		get {
			var shown = Set<LauncherInfoAnswer>()
			if showsGameVersion { shown.insert(.gameVersion) }
			if showsServerResetCountdown { shown.insert(.serverTime) }
			return shown
		}
		set {
			showsGameVersion = newValue.contains(.gameVersion)
			showsServerResetCountdown = newValue.contains(.serverTime)
		}
	}
}

/// How the launcher keeps up with new versions and project notices, answered during setup.
enum UpdateCheckAnswer: CaseIterable, Sendable {
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
