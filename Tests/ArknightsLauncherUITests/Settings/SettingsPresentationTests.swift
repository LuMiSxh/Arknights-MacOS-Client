// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import CoreGraphics
import Testing

@testable import ArknightsLauncherUI

private let screen = GameScreenMetrics(
	visibleSize: CGSize(width: 1920, height: 1055),
	pixelSize: CGSize(width: 3840, height: 2160),
	titleBarHeight: 28
)
private let native = GameDisplaySize(width: 3840, height: 2160)

@MainActor
@Test
func settingsOpenOnGameAndNoLongerOfferGeneral() {
	let sections = SettingsSection.allCases.map(\.rawValue)
	#expect(SettingsSection.initial == .game)
	#expect(Array(sections.prefix(3)) == ["game", "appearance", "audio"])
	#expect(!sections.contains("general"))
}

@MainActor
@Test
func summaryNamesWindowChoiceAndPictureWithoutNumbers() {
	var options = GameLaunchOptions.default
	options.windowSize = GameWindowSizeChoice.fillScreen.size(on: screen)
	#expect(
		GameDisplaySummary.text(for: options, screen: screen, native: native)
			== "The game opens in a window that fills your screen and looks sharp.")

	options.windowSize = GameWindowSizeChoice.leaveRoom.size(on: screen)
	options.displayMode = .borderlessWindow
	options.renderingMode = .metalFX
	#expect(
		GameDisplaySummary.text(for: options, screen: screen, native: native)
			== "The game opens in a window without a title bar that leaves room for other apps and plays smoothly."
	)

	options.windowSize = GameDisplaySize(width: 1000, height: 600)
	options.displayMode = .windowed
	options.renderingMode = .lightweight
	#expect(
		GameDisplaySummary.text(for: options, screen: screen, native: native)
			== "The game opens in a window and saves battery.")
}

@MainActor
@Test
func summaryDescribesFullscreenDetailAndGameControlledDisplay() {
	var options = GameLaunchOptions.default
	options.displayMode = .fullscreen
	options.fullscreenResolution = .native
	#expect(
		GameDisplaySummary.text(for: options, screen: screen, native: native)
			== "The game fills your screen and looks sharp.")

	options.fullscreenResolution = GameFullscreenDetail.lighter.resolution(native: native)
	#expect(
		GameDisplaySummary.text(for: options, screen: screen, native: native)
			== "The game fills your screen at lighter detail and looks sharp.")

	options.usesGameSettings = true
	#expect(
		GameDisplaySummary.text(for: options, screen: screen, native: native)
			== SettingsStrings.displayHandledInGame)
}
