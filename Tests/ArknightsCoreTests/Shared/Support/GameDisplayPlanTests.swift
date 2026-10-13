// SPDX-License-Identifier: MPL-2.0

import CoreGraphics
import Testing

@testable import ArknightsCore

private func size(_ width: Int, _ height: Int) -> GameDisplaySize {
	GameDisplaySize(width: width, height: height)
}

@Test(
	arguments: [
		// (rendering, display mode, native fullscreen, in-game settings, backing scale, render size, scaling)
		(
			GameRenderingMode.retina, GameDisplayMode.windowed, false, false, 2.0, size(2560, 1440),
			.native
		),
		(.metalFX, .windowed, false, false, 2.0, size(1280, 720), .metalFX),
		(.standard, .windowed, false, false, 2.0, size(1280, 720), .stretched),
		(.retina, .windowed, false, false, 1.0, size(1280, 720), .native),
		(.metalFX, .windowed, false, false, 1.0, size(1280, 720), .native),
		(.retina, .fullscreen, false, false, 2.0, size(1920, 1080), nil),
		(.standard, .fullscreen, false, false, 2.0, size(1920, 1080), nil),
		(.retina, .fullscreen, true, false, 2.0, size(6016, 3384), .native),
		(.metalFX, .fullscreen, true, false, 2.0, size(3008, 1692), .metalFX),
		(.standard, .fullscreen, true, false, 2.0, size(3008, 1692), .stretched),
		(.retina, .windowed, false, true, 2.0, nil, nil),
	]
		as [(
			GameRenderingMode, GameDisplayMode, Bool, Bool, Double, GameDisplaySize?,
			GameDisplayPlan.Scaling?
		)])
func windowedPlansRenderTheWindowSizeTimesTheGamePixelDensity(
	renderingMode: GameRenderingMode,
	displayMode: GameDisplayMode,
	native: Bool,
	usesGameSettings: Bool,
	backingScale: Double,
	renderSize: GameDisplaySize?,
	scaling: GameDisplayPlan.Scaling?
) {
	var options = GameLaunchOptions(
		displayMode: displayMode,
		resolution: .fullHD,
		windowSize: .defaultWindow,
		usesGameSettings: usesGameSettings,
		renderingMode: renderingMode
	)
	var display: GameFullscreenDisplay?
	if native {
		options.fullscreenResolution = .native
		display = GameFullscreenDisplay(pointSize: size(3008, 1692), backingScale: 2)
	}

	let plan = GameDisplayPlan(
		options: options, backingScaleFactor: CGFloat(backingScale), fullscreenDisplay: display)

	#expect(plan.renderSize == renderSize)
	if let scaling { #expect(plan.scaling == scaling) }
	if usesGameSettings { #expect(plan.gamePixelsPerPoint == 2) }
}
