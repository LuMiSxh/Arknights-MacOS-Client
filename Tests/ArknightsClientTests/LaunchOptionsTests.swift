// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func defaultLaunchOptionsFavorCompatibleWindow() {
	#expect(GameLaunchOptions.default.displayMode == .windowed)
	#expect(GameLaunchOptions.default.resolution == .hd)
	#expect(GameLaunchOptions.default.usesGameSettings)
	#expect(GameLaunchOptions.default.usesHighResolutionMode)
	#expect(!GameLaunchOptions.default.usesMetalPerformanceHUD)
	#expect(!GameLaunchOptions.default.usesGameMode)
	#expect(GameLaunchOptions.default.playerArguments.isEmpty)
}

@Test
func legacyLaunchOptionsEnableHighResolutionModeWhenDecoded() throws {
	let data = Data(
		#"{"displayMode":"windowed","resolution":"1280x720","usesGameSettings":true}"#.utf8
	)
	let options = try JSONDecoder().decode(GameLaunchOptions.self, from: data)

	#expect(options.usesHighResolutionMode)
	#expect(!options.usesMetalPerformanceHUD)
	#expect(!options.usesGameMode)
}

@Test
func fullscreenLaunchArgumentsUseSelectedResolution() {
	let options = GameLaunchOptions(
		displayMode: .fullscreen,
		resolution: .quadHD,
		usesGameSettings: false
	)

	#expect(
		options.playerArguments
			== ["-screen-fullscreen", "1", "-screen-width", "2560", "-screen-height", "1440"]
	)
}

@Test
func windowedLaunchArgumentsDisableFullscreen() {
	let options = GameLaunchOptions(
		displayMode: .windowed,
		resolution: .fullHD,
		usesGameSettings: false
	)

	#expect(
		options.playerArguments
			== ["-screen-fullscreen", "0", "-screen-width", "1920", "-screen-height", "1080"]
	)
}

@Test
func borderlessLaunchArgumentsAddPopupWindowFlag() {
	let options = GameLaunchOptions(
		displayMode: .borderlessWindow,
		resolution: .ultraHD,
		usesGameSettings: false
	)

	#expect(
		options.playerArguments
			== [
				"-screen-fullscreen", "0", "-screen-width", "3840", "-screen-height", "2160",
				"-popupwindow",
			]
	)
}
