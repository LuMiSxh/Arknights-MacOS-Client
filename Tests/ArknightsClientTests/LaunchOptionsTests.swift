// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

@Test
func defaultLaunchOptionsFavorCompatibleWindow() {
	#expect(GameLaunchOptions.default.displayMode == .windowed)
	#expect(GameLaunchOptions.default.resolution == .hd)
}

@Test
func fullscreenLaunchArgumentsUseSelectedResolution() {
	let options = GameLaunchOptions(displayMode: .fullscreen, resolution: .quadHD)

	#expect(
		options.playerArguments
			== ["-screen-fullscreen", "1", "-screen-width", "2560", "-screen-height", "1440"]
	)
}

@Test
func windowedLaunchArgumentsDisableFullscreen() {
	let options = GameLaunchOptions(displayMode: .windowed, resolution: .fullHD)

	#expect(
		options.playerArguments
			== ["-screen-fullscreen", "0", "-screen-width", "1920", "-screen-height", "1080"]
	)
}

@Test
func borderlessLaunchArgumentsAddPopupWindowFlag() {
	let options = GameLaunchOptions(displayMode: .borderlessWindow, resolution: .ultraHD)

	#expect(
		options.playerArguments
			== [
				"-screen-fullscreen", "0", "-screen-width", "3840", "-screen-height", "2160",
				"-popupwindow",
			]
	)
}
