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

@Test(arguments: [
	(GameRenderingMode.retina, 6016, GameDisplayPlan.Scaling.native),
	(.metalFX, 3008, .metalFX),
	(.lightweight, 3008, .stretched),
])
func nativeFullscreenPlansRenderThePrimaryDisplaySize(
	renderingMode: GameRenderingMode, renderWidth: Int, scaling: GameDisplayPlan.Scaling
) {
	var native = options(renderingMode, displayMode: .fullscreen)
	native.fullscreenResolution = .native
	let display = GameFullscreenDisplay(
		pointSize: GameDisplaySize(width: 3008, height: 1692), backingScale: 2)

	let plan = GameDisplayPlan(options: native, backingScaleFactor: 2, fullscreenDisplay: display)

	#expect(plan.renderSize?.width == renderWidth)
	#expect(plan.renderSize?.height == renderWidth * 1692 / 3008)
	#expect(plan.scaling == scaling)
	// A display without Retina scaling shows its points one to one.
	let standard = GameFullscreenDisplay(pointSize: display.pointSize, backingScale: 1)
	#expect(standard.pixelSize == display.pointSize)
	#expect(standard.drawnSize(showing: display.pointSize, retina: false) == display.pointSize)
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
