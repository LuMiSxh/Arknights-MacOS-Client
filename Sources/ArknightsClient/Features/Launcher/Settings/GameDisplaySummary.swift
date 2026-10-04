// SPDX-License-Identifier: MPL-2.0

/// Says in plain words what the saved display choices will show, without any numbers.
enum GameDisplaySummary {
	static func text(
		for options: GameLaunchOptions, screen: GameScreenMetrics?, native: GameDisplaySize?
	) -> String {
		guard !options.usesGameSettings else { return SettingsStrings.displayHandledInGame }
		let placement = placement(for: options, screen: screen, native: native)
		return "\(placement) \(picture(options.renderingMode))."
	}

	private static func placement(
		for options: GameLaunchOptions, screen: GameScreenMetrics?, native: GameDisplaySize?
	) -> String {
		if options.displayMode == .fullscreen {
			let detail = GameFullscreenDetail.matching(options.fullscreenResolution, native: native)
			let clause =
				switch detail {
				case .balanced?: " at balanced detail"
				case .lighter?: " at lighter detail"
				case .full?, nil: ""
				}
			return "The game fills your screen\(clause)"
		}
		let window =
			options.displayMode == .windowed
			? "The game opens in a window" : "The game opens in a window without a title bar"
		let choice = screen.flatMap { GameWindowSizeChoice.matching(options.windowSize, on: $0) }
		let clause =
			switch choice {
			case .fillScreen?: " that fills your screen"
			case .leaveRoom?: " that leaves room for other apps"
			case nil: ""
			}
		return window + clause
	}

	private static func picture(_ mode: GameRenderingMode) -> String {
		switch mode {
		case .retina: "and looks sharp"
		case .metalFX: "and plays smoothly"
		case .lightweight: "and saves battery"
		}
	}
}
