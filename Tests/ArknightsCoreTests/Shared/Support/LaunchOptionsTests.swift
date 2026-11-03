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

@Test(arguments: [
	// (stored size, visible screen in points, launch size). The fill size is the visible screen
	// less the 28-point title bar, so 1600 × 928 leaves 1600 × 900.
	(
		GameDisplaySize(width: 1280, height: 720), CGSize(width: 1600, height: 928),
		GameDisplaySize(width: 1280, height: 720)
	),
	(
		GameDisplaySize(width: 1920, height: 720), CGSize(width: 1600, height: 928),
		GameDisplaySize(width: 1600, height: 600)
	),
	(
		GameDisplaySize(width: 1000, height: 1200), CGSize(width: 1600, height: 928),
		GameDisplaySize(width: 750, height: 900)
	),
	(
		GameDisplaySize(width: 3840, height: 2160), CGSize(width: 1600, height: 928),
		GameDisplaySize(width: 1600, height: 900)
	),
	// Beyond the custom maximum, even on a screen that could show it.
	(
		GameDisplaySize(width: 10000, height: 5000), CGSize(width: 16000, height: 9000),
		GameDisplaySize(width: 8192, height: 4096)
	),
])
func launchWindowSizeScalesOversizedWindowsAndKeepsTheStoredSize(
	stored: GameDisplaySize, visibleSize: CGSize, expected: GameDisplaySize
) {
	let options = GameLaunchOptions(displayMode: .windowed, resolution: .hd, windowSize: stored)
	let screen = GameScreenMetrics(visibleSize: visibleSize, pixelSize: .zero)

	#expect(options.launchWindowSize(on: screen) == expected)
	#expect(options.windowSize == stored)
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
	#expect(options.frameRateLimit == .fps120)

	let retired = try decode(
		#"{"displayMode":"windowed","resolution":"1280x720","usesPreciseScrolling":true}"#)
	let current = try decode(#"{"displayMode":"windowed","resolution":"1280x720"}"#)
	#expect(retired == current)

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

@Test(arguments: [
	(GameFrameRateLimit.fps120, GameFrameRateLimit.fps30, GameFrameRateLimit.fps30),
	(GameFrameRateLimit.fps120, GameFrameRateLimit.fps60, GameFrameRateLimit.fps60),
	(GameFrameRateLimit.fps60, GameFrameRateLimit.fps30, GameFrameRateLimit.fps30),
	(GameFrameRateLimit.fps60, GameFrameRateLimit.fps60, GameFrameRateLimit.fps60),
	(GameFrameRateLimit.fps30, GameFrameRateLimit.fps60, GameFrameRateLimit.fps30),
])
func batterySaverNeverRaisesTheFrameRateLimit(
	userLimit: GameFrameRateLimit,
	saverLimit: GameFrameRateLimit,
	expected: GameFrameRateLimit
) {
	let options = GameLaunchOptions(
		displayMode: .windowed, resolution: .hd, frameRateLimit: userLimit
	).applyingBatterySaver(frameRateLimit: saverLimit, metalFXSupported: true)
	#expect(options.frameRateLimit == expected)
}

@Test(arguments: [
	(GameRenderingMode.retina, true, GameRenderingMode.metalFX),
	(GameRenderingMode.retina, false, GameRenderingMode.standard),
	(GameRenderingMode.metalFX, true, GameRenderingMode.metalFX),
	(GameRenderingMode.metalFX, false, GameRenderingMode.metalFX),
	(GameRenderingMode.standard, true, GameRenderingMode.standard),
	(GameRenderingMode.standard, false, GameRenderingMode.standard),
])
func batterySaverDowngradesOnlyRetinaRendering(
	renderingMode: GameRenderingMode,
	metalFXSupported: Bool,
	expected: GameRenderingMode
) {
	let options = GameLaunchOptions(
		displayMode: .windowed, resolution: .hd, renderingMode: renderingMode
	).applyingBatterySaver(frameRateLimit: .fps30, metalFXSupported: metalFXSupported)
	#expect(options.renderingMode == expected)
}

@Test(arguments: GameRenderingMode.allCases)
func batterySaverLeavesRenderingAloneWhenGameSettingsApply(renderingMode: GameRenderingMode) {
	let options = GameLaunchOptions(
		displayMode: .windowed, resolution: .hd, usesGameSettings: true,
		renderingMode: renderingMode
	).applyingBatterySaver(frameRateLimit: .fps30, metalFXSupported: true)
	#expect(options.renderingMode == renderingMode)
}

@Test
func batterySaverTurnsOffGameModeAndKeepsHUDAndSynchronization() {
	let options = GameLaunchOptions(
		displayMode: .windowed, resolution: .hd, usesMetalPerformanceHUD: true,
		usesGameMode: true, synchronizationMode: .esync
	).applyingBatterySaver(frameRateLimit: .fps30, metalFXSupported: true)
	#expect(!options.usesGameMode)
	#expect(options.usesMetalPerformanceHUD)
	#expect(options.synchronizationMode == .esync)
}
