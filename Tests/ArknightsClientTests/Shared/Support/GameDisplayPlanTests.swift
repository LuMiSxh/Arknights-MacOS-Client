// SPDX-License-Identifier: MPL-2.0

import CoreGraphics
import Testing

@testable import ArknightsClient

private func options(
	_ renderingMode: GameRenderingMode,
	displayMode: GameDisplayMode = .windowed,
	usesGameSettings: Bool = false
) -> GameLaunchOptions {
	GameLaunchOptions(
		displayMode: displayMode,
		resolution: .fullHD,
		windowSize: .defaultWindow,
		usesGameSettings: usesGameSettings,
		renderingMode: renderingMode
	)
}

@Test(arguments: [
	(GameRenderingMode.retina, 2.0, 2560, GameDisplayPlan.Scaling.native),
	(.metalFX, 2.0, 1280, .metalFX),
	(.lightweight, 2.0, 1280, .stretched),
	(.retina, 1.0, 1280, .native),
	(.metalFX, 1.0, 1280, .native),
])
func windowedPlansRenderTheWindowSizeTimesTheGamePixelDensity(
	renderingMode: GameRenderingMode,
	backingScale: Double,
	renderWidth: Int,
	scaling: GameDisplayPlan.Scaling
) {
	let plan = GameDisplayPlan(
		options: options(renderingMode), backingScaleFactor: CGFloat(backingScale))

	#expect(plan.renderSize?.width == renderWidth)
	#expect(plan.renderSize?.height == renderWidth * 9 / 16)
	#expect(plan.scaling == scaling)
}

@Test(arguments: GameRenderingMode.allCases)
func fullscreenPlansKeepTheGameResolution(renderingMode: GameRenderingMode) {
	let plan = GameDisplayPlan(
		options: options(renderingMode, displayMode: .fullscreen), backingScaleFactor: 2)

	#expect(plan.renderSize == GameDisplaySize(width: 1920, height: 1080))
}

@Test
func inGameSettingsLeaveTheRenderSizeToArknights() {
	let plan = GameDisplayPlan(
		options: options(.retina, usesGameSettings: true), backingScaleFactor: 2)

	#expect(plan.renderSize == nil)
	#expect(plan.gamePixelsPerPoint == 2)
	#expect(
		SettingsStrings.inGameResolutionNote(window: .defaultWindow, pixelsPerPoint: 2)
			.contains("choose 2560 × 1440 in the game for a 1280 × 720 window")
	)
}

@Test
func renderSummariesNameTheDrawnAndShownSizes() throws {
	let metalFX = GameDisplayPlan(options: options(.metalFX), backingScaleFactor: 2)
	let size = try #require(metalFX.renderSize)

	#expect(
		SettingsStrings.renderSummary(metalFX, size: size, fullscreen: false)
			== "The game draws 1280 × 720 pixels and MetalFX upscales them to 2560 × 1440."
	)
	#expect(
		SettingsStrings.renderSummary(metalFX, size: size, fullscreen: true)
			== "The game draws 1280 × 720 pixels and MetalFX upscales them to fill the screen."
	)
}

@Test
func windowOptionsFitTheScreenAndKeepTheCurrentSize() {
	let custom = GameDisplaySize(width: 1000, height: 600)
	let options = GameDisplaySize.windowOptions(
		fitting: CGSize(width: 1512, height: 944), current: custom)

	#expect(options.contains(custom))
	#expect(options.contains(GameDisplaySize(width: 1440, height: 900)))
	#expect(!options.contains(GameDisplaySize(width: 1600, height: 900)))
	#expect(options == options.sorted { ($0.width, $0.height) < ($1.width, $1.height) })
	#expect(
		GameDisplaySize.windowOptions(fitting: nil, current: .defaultWindow)
			== GameDisplaySize.windowPresets
	)
}
