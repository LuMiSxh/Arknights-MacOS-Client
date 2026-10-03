// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func gameResolutionsMatchOfficialClientOptions() {
	#expect(
		GameResolution.allCases.map(\.rawValue)
			== [
				"3840x2160", "2560x1440", "2048x1080", "1920x1200", "1920x1080",
				"1680x1050", "1600x1200", "1600x1024", "1600x900", "1440x1080",
				"1360x768", "1280x960", "1280x800", "1280x768", "1280x720", "1176x664",
				"1152x864", "1024x768", "800x600", "720x480", "640x480",
			]
	)
	for resolution in GameResolution.allCases {
		#expect(resolution.rawValue == "\(resolution.width)x\(resolution.height)")
	}
}

@Test
func defaultLaunchOptionsFavorCompatibleWindow() {
	#expect(GameLaunchOptions.default.displayMode == .windowed)
	#expect(GameLaunchOptions.default.resolution == .hd)
	#expect(!GameLaunchOptions.default.usesGameSettings)
	#expect(GameLaunchOptions.default.windowSize == .defaultWindow)
	#expect(GameLaunchOptions.default.renderingMode == .retina)
	#expect(!GameLaunchOptions.default.usesMetalPerformanceHUD)
	#expect(!GameLaunchOptions.default.usesGameMode)
	#expect(GameLaunchOptions.default.synchronizationMode == .msync)
	#expect(
		GameLaunchOptions.default.playerArguments(gamePixelsPerPoint: 2)
			== ["-screen-fullscreen", "0", "-screen-width", "2560", "-screen-height", "1440"]
	)
}

@Test
func legacyLaunchOptionsDecodeWithStableDefaultsAndIgnoreRetiredFields() throws {
	let data = Data(
		#"{"displayMode":"windowed","resolution":"1280x720","usesGameSettings":true}"#.utf8
	)
	let options = try JSONDecoder().decode(GameLaunchOptions.self, from: data)

	#expect(options.renderingMode == .retina)
	#expect(options.windowSize == .defaultWindow)
	#expect(!options.usesMetalPerformanceHUD)
	#expect(!options.usesGameMode)
	#expect(options.synchronizationMode == .msync)

	let retiredFieldData = Data(
		#"{"displayMode":"windowed","resolution":"1280x720","usesPreciseScrolling":true}"#.utf8
	)

	let retiredFieldOptions = try JSONDecoder().decode(
		GameLaunchOptions.self, from: retiredFieldData)

	let currentFieldOptions = try JSONDecoder().decode(
		GameLaunchOptions.self,
		from: Data(#"{"displayMode":"windowed","resolution":"1280x720"}"#.utf8)
	)
	#expect(retiredFieldOptions == currentFieldOptions)
	#expect(retiredFieldOptions.usesGameSettings)
}

@Test
func launchDiagnosticsRecordEveryOptionAppliedToWine() throws {
	let sessionID = try #require(UUID(uuidString: "B59431CE-EC59-4CE0-9677-752876A01001"))
	let options = GameLaunchOptions(
		displayMode: .fullscreen,
		resolution: .quadHD,
		windowSize: GameDisplaySize(width: 1600, height: 900),
		usesGameSettings: false,
		renderingMode: .metalFX,
		usesMetalPerformanceHUD: true,
		usesGameMode: true,
		synchronizationMode: .esync
	)

	let diagnostic = GameSessionController.launchDiagnostics(
		sessionID: sessionID,
		region: .korea,
		options: options,
		graphicsDiagnosticsEnabled: true
	)

	#expect(diagnostic.contains("session=B59431CE-EC59-4CE0-9677-752876A01001"))
	#expect(diagnostic.contains("region=Korea"))
	#expect(diagnostic.contains("usesGameSettings=false"))
	#expect(diagnostic.contains("displayMode=Fullscreen"))
	#expect(diagnostic.contains("resolution=2560x1440"))
	#expect(diagnostic.contains("windowSize=1600x900"))
	#expect(diagnostic.contains("rendering=metalFX"))
	#expect(diagnostic.contains("metalHUD=true"))
	#expect(diagnostic.contains("gameMode=true"))
	#expect(diagnostic.contains("synchronization=ESYNC"))
	#expect(diagnostic.contains("graphicsDiagnostics=true"))
}

@Test(arguments: [
	(
		GameDisplayMode.fullscreen, 2,
		["-screen-fullscreen", "1", "-screen-width", "2560", "-screen-height", "1440"]
	),
	(
		GameDisplayMode.windowed, 1,
		["-screen-fullscreen", "0", "-screen-width", "1280", "-screen-height", "720"]
	),
	(
		GameDisplayMode.windowed, 2,
		["-screen-fullscreen", "0", "-screen-width", "2560", "-screen-height", "1440"]
	),
	(
		GameDisplayMode.borderlessWindow, 2,
		[
			"-screen-fullscreen", "0", "-screen-width", "2560", "-screen-height", "1440",
			"-popupwindow",
		]
	),
])
func launchArgumentsConvertWindowPointsButKeepFullscreenPixels(
	displayMode: GameDisplayMode,
	gamePixelsPerPoint: Int,
	expected: [String]
) {
	let options = GameLaunchOptions(
		displayMode: displayMode,
		resolution: .quadHD,
		windowSize: .defaultWindow,
		usesGameSettings: false
	)

	#expect(options.playerArguments(gamePixelsPerPoint: gamePixelsPerPoint) == expected)
}

@Test
func nativeFullscreenRendersTheDisplaySizeOnThePrimaryDisplay() throws {
	var options = GameLaunchOptions(
		displayMode: .fullscreen, resolution: .ultraHD, usesGameSettings: false)
	options.fullscreenResolution = .native
	let display = GameFullscreenDisplay(
		pointSize: GameDisplaySize(width: 3008, height: 1692), backingScale: 2)

	#expect(
		options.playerArguments(gamePixelsPerPoint: 2, fullscreenDisplay: display)
			== [
				"-screen-fullscreen", "1", "-screen-width", "6016", "-screen-height", "3384",
				"-monitor", "1",
			]
	)
	// MetalFX and Lightweight show the same resolution from one pixel per point.
	#expect(
		options.playerArguments(gamePixelsPerPoint: 1, fullscreenDisplay: display)
			== [
				"-screen-fullscreen", "1", "-screen-width", "3008", "-screen-height", "1692",
				"-monitor", "1",
			]
	)
	// Without a known display, the official resolution stays in effect.
	#expect(
		options.playerArguments(gamePixelsPerPoint: 2)
			== ["-screen-fullscreen", "1", "-screen-width", "3840", "-screen-height", "2160"]
	)

	let decoded = try JSONDecoder().decode(
		GameLaunchOptions.self, from: JSONEncoder().encode(options))
	#expect(decoded == options)
	let older = try JSONDecoder().decode(
		GameLaunchOptions.self, from: Data(#"{"displayMode":"fullscreen"}"#.utf8))
	#expect(
		older.fullscreenResolution == .fixed(GameDisplaySize(GameLaunchOptions.default.resolution)))
	let official = try JSONDecoder().decode(
		GameLaunchOptions.self, from: Data(#"{"resolution":"2560x1440"}"#.utf8))
	#expect(official.fullscreenResolution == .fixed(GameDisplaySize(width: 2560, height: 1440)))
}

@Test
func fixedFullscreenSizesKeepTheClosestOfficialResolutionForOlderLaunchers() throws {
	var options = GameLaunchOptions.default
	options.displayMode = .fullscreen
	let fiveK = GameDisplaySize(width: 5120, height: 2880)
	options.selectFullscreen(.fixed(fiveK), native: GameDisplaySize(width: 6016, height: 3384))

	#expect(options.fullscreenResolution == .fixed(fiveK))
	#expect(options.resolution == .ultraHD)
	#expect(options.playerArguments(gamePixelsPerPoint: 2).contains("5120"))
	#expect(!options.playerArguments(gamePixelsPerPoint: 2).contains("-monitor"))

	options.selectFullscreen(.native, native: GameDisplaySize(width: 2940, height: 1912))
	#expect(options.resolution == .quadHD)
	let stored = try JSONEncoder().encode(options)
	#expect(String(decoding: stored, as: UTF8.self).contains(#""fullscreenResolution":"native""#))
}

@Test(arguments: [
	// Retina-on launcher overrides stored pixels; keep the window they opened.
	(#"{"resolution":"2560x1440","usesGameSettings":false}"#, 1280, 720, GameRenderingMode.retina),
	(
		#"{"resolution":"1920x1080","usesGameSettings":false,"usesHighResolutionMode":false}"#,
		1920, 1080, .lightweight
	),
	// In-game settings never used the stored resolution, so the window starts at the default.
	(#"{"resolution":"2560x1440","usesGameSettings":true}"#, 1280, 720, .retina),
	// Halving below the smallest supported window falls back to the default size.
	(#"{"resolution":"640x480","usesGameSettings":false}"#, 1280, 720, .retina),
	(#"{"windowSize":{"width":10,"height":10},"usesGameSettings":false}"#, 1280, 720, .retina),
])
func legacyResolutionMigratesToWindowSizeAndRenderingMode(
	json: String, width: Int, height: Int, renderingMode: GameRenderingMode
) throws {
	let options = try JSONDecoder().decode(GameLaunchOptions.self, from: Data(json.utf8))

	#expect(options.windowSize == GameDisplaySize(width: width, height: height))
	#expect(options.renderingMode == renderingMode)
}

@Test(arguments: GameRenderingMode.allCases)
func launchOptionsRoundTripAndKeepTheLegacyRetinaFlag(renderingMode: GameRenderingMode) throws {
	let options = GameLaunchOptions(
		displayMode: .borderlessWindow,
		resolution: .fullHD,
		windowSize: GameDisplaySize(width: 1600, height: 900),
		usesGameSettings: false,
		renderingMode: renderingMode
	)
	let data = try JSONEncoder().encode(options)
	let object = try #require(
		try JSONSerialization.jsonObject(with: data) as? [String: Any])

	#expect(try JSONDecoder().decode(GameLaunchOptions.self, from: data) == options)
	#expect(object["usesHighResolutionMode"] as? Bool == (renderingMode == .retina))
}
