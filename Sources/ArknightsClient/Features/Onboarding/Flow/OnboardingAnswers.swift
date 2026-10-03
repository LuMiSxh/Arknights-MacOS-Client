// SPDX-License-Identifier: MPL-2.0

import AppKit

/// The screen setup answers are sized for: usable area in points and the panel's full pixel size.
struct GameScreenMetrics: Equatable, Sendable {
	let visibleSize: CGSize
	let pixelSize: CGSize

	@MainActor static var main: GameScreenMetrics? {
		guard let screen = NSScreen.main else { return nil }
		return GameScreenMetrics(
			visibleSize: screen.visibleFrame.size,
			pixelSize: CGSize(
				width: screen.frame.width * screen.backingScaleFactor,
				height: screen.frame.height * screen.backingScaleFactor
			)
		)
	}

	/// The largest 16:9 window preset, matching the game's layout, that fits within the
	/// recommended share of the screen.
	var recommendedWindowSize: GameDisplaySize {
		let share = AppConstants.Game.recommendedWindowScreenShare
		let maximumWidth = visibleSize.width * share
		let maximumHeight = visibleSize.height * share
		let widescreen = GameDisplaySize.windowPresets.filter { $0.width * 9 == $0.height * 16 }
		return widescreen.last {
			CGFloat($0.width) <= maximumWidth && CGFloat($0.height) <= maximumHeight
		} ?? widescreen[0]
	}

	/// The official game resolution with the most pixels that the panel can show unscaled.
	var fullscreenResolution: GameResolution {
		GameResolution.largest(
			fitting: GameDisplaySize(width: Int(pixelSize.width), height: Int(pixelSize.height)))
			?? .fullHD
	}
}

/// Where the game appears, answered during setup.
enum GamePlacementAnswer: CaseIterable, Sendable {
	case window
	case fullscreen
}

/// The setup assistant's display questions. Every answer lets the launcher size the game for
/// the current screen, so players never have to calculate resolutions.
struct GameDisplayAnswers: Equatable, Sendable {
	var placement: GamePlacementAnswer
	var rendering: GameRenderingMode

	static let recommended = GameDisplayAnswers(placement: .window, rendering: .retina)

	init(placement: GamePlacementAnswer, rendering: GameRenderingMode) {
		self.placement = placement
		self.rendering = rendering
	}

	/// Reads the answers back from saved options, so returning to setup shows earlier choices.
	init(_ options: GameLaunchOptions) {
		placement = options.displayMode == .fullscreen ? .fullscreen : .window
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
			options.windowSize = screen.recommendedWindowSize
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
