// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

@Test(arguments: [
	(
		GameDisplayMode.fullscreen, false, false, 2,
		["-screen-fullscreen", "1", "-screen-width", "2560", "-screen-height", "1440"]
	),
	(
		GameDisplayMode.windowed, false, false, 1,
		["-screen-fullscreen", "0", "-screen-width", "1280", "-screen-height", "720"]
	),
	(
		GameDisplayMode.windowed, false, false, 2,
		["-screen-fullscreen", "0", "-screen-width", "2560", "-screen-height", "1440"]
	),
	(
		GameDisplayMode.borderlessWindow, false, false, 2,
		[
			"-screen-fullscreen", "0", "-screen-width", "2560", "-screen-height", "1440",
			"-popupwindow",
		]
	),
	(
		GameDisplayMode.fullscreen, true, true, 2,
		[
			"-screen-fullscreen", "1", "-screen-width", "6016", "-screen-height", "3384",
			"-monitor", "1",
		]
	),
	(
		GameDisplayMode.fullscreen, true, true, 1,
		[
			"-screen-fullscreen", "1", "-screen-width", "3008", "-screen-height", "1692",
			"-monitor", "1",
		]
	),
	// Without a known display, the official resolution stays in effect.
	(
		GameDisplayMode.fullscreen, true, false, 2,
		["-screen-fullscreen", "1", "-screen-width", "2560", "-screen-height", "1440"]
	),
])
func launchArgumentsConvertWindowPointsButKeepFullscreenPixels(
	displayMode: GameDisplayMode,
	native: Bool,
	knownDisplay: Bool,
	gamePixelsPerPoint: Int,
	expected: [String]
) {
	var options = GameLaunchOptions(
		displayMode: displayMode,
		resolution: .quadHD,
		windowSize: .defaultWindow,
		usesGameSettings: false
	)
	if native { options.fullscreenResolution = .native }
	let display =
		knownDisplay
		? GameFullscreenDisplay(
			pointSize: GameDisplaySize(width: 3008, height: 1692), backingScale: 2) : nil

	#expect(
		options.playerArguments(gamePixelsPerPoint: gamePixelsPerPoint, fullscreenDisplay: display)
			== expected)
}

@Test
func legacyLaunchOptionsDecodeWithStableDefaultsAndIgnoreRetiredFields() throws {
	func decode(_ json: String) throws -> GameLaunchOptions {
		try JSONDecoder().decode(GameLaunchOptions.self, from: Data(json.utf8))
	}

	let options = try decode(
		#"{"displayMode":"windowed","resolution":"1280x720","usesGameSettings":true}"#)
	#expect(options.renderingMode == .retina)
	#expect(options.windowSize == .defaultWindow)
	#expect(!options.usesMetalPerformanceHUD)
	#expect(!options.usesGameMode)
	#expect(options.synchronizationMode == .msync)

	let retired = try decode(
		#"{"displayMode":"windowed","resolution":"1280x720","usesPreciseScrolling":true}"#)
	let current = try decode(#"{"displayMode":"windowed","resolution":"1280x720"}"#)
	#expect(retired == current)
	#expect(retired.usesGameSettings)

	// (stored JSON, window width, window height, rendering mode)
	let migrations: [(String, Int, Int, GameRenderingMode)] = [
		// Retina-on launcher overrides stored pixels; keep the window they opened.
		(#"{"resolution":"2560x1440","usesGameSettings":false}"#, 1280, 720, .retina),
		(
			#"{"resolution":"1920x1080","usesGameSettings":false,"usesHighResolutionMode":false}"#,
			1920, 1080, .standard
		),
		// In-game settings never used the stored resolution, so the window starts at the default.
		(#"{"resolution":"2560x1440","usesGameSettings":true}"#, 1280, 720, .retina),
		// Halving below the smallest supported window falls back to the default size.
		(#"{"resolution":"640x480","usesGameSettings":false}"#, 1280, 720, .retina),
		(#"{"windowSize":{"width":10,"height":10},"usesGameSettings":false}"#, 1280, 720, .retina),
	]
	for (json, width, height, renderingMode) in migrations {
		let migrated = try decode(json)
		#expect(migrated.windowSize == GameDisplaySize(width: width, height: height))
		#expect(migrated.renderingMode == renderingMode)
	}

	// Older launchers stored only the official resolution; newer ones add a fullscreen value.
	#expect(
		try decode(#"{"displayMode":"fullscreen"}"#).fullscreenResolution
			== .fixed(GameLaunchOptions.default.resolution))
	#expect(
		try decode(#"{"resolution":"2560x1440"}"#).fullscreenResolution
			== .fixed(GameDisplaySize(width: 2560, height: 1440)))
	for value in ["", "0x0", "wide", "5120x"] {
		#expect(GameFullscreenResolution(storageValue: value) == nil)
	}

	for renderingMode in GameRenderingMode.allCases {
		var stored = GameLaunchOptions(
			displayMode: .borderlessWindow,
			resolution: .fullHD,
			windowSize: GameDisplaySize(width: 1600, height: 900),
			usesGameSettings: false,
			renderingMode: renderingMode
		)
		stored.fullscreenResolution = .native
		let data = try JSONEncoder().encode(stored)
		let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
		#expect(try JSONDecoder().decode(GameLaunchOptions.self, from: data) == stored)
		#expect(object["usesHighResolutionMode"] as? Bool == (renderingMode == .retina))
	}
}
