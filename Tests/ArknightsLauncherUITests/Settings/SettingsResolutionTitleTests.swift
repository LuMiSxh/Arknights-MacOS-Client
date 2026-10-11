// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsCore
@testable import ArknightsLauncherUI

@MainActor
@Test
func onlyWellKnownResolutionsAreNamed() {
	func size(_ width: Int, _ height: Int) -> GameDisplaySize {
		GameDisplaySize(width: width, height: height)
	}

	#expect(SettingsStrings.resolutionTitle(size(2560, 1440)) == "2560 × 1440 (WQHD)")
	#expect(SettingsStrings.resolutionTitle(size(1920, 1080)) == "1920 × 1080 (Full HD)")
	#expect(SettingsStrings.resolutionTitle(size(1920, 1200)) == "1920 × 1200")
	#expect(SettingsStrings.resolutionTitle(size(4480, 2520)) == "4480 × 2520")
	#expect(SettingsStrings.nativeResolutionTitle(size(6016, 3384)) == "Native (6016 × 3384)")
	#expect(SettingsStrings.nativeResolutionTitle(nil) == "Native")
}

@MainActor
@Test
func inGameResolutionNoteNamesTheMatchingGameResolution() {
	#expect(
		SettingsStrings.inGameResolutionNote(window: .defaultWindow, pixelsPerPoint: 2)
			.contains("choose 2560 × 1440 in the game for a 1280 × 720 window")
	)
}
