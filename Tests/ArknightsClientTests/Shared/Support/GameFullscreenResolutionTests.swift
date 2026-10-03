// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

private func size(_ width: Int, _ height: Int) -> GameDisplaySize {
	GameDisplaySize(width: width, height: height)
}

@Test(arguments: [
	(size(6016, 3384), [size(5760, 3240), size(5120, 2880), size(4480, 2520)]),
	(size(5120, 2880), [size(4480, 2520)]),
	(size(3840, 2160), []),
	(size(2940, 1912), []),
])
func displaysBeyondFourKGetSizesInTheirOwnShape(
	native: GameDisplaySize, generated: [GameDisplaySize]
) {
	#expect(GameFullscreenResolution.generatedSizes(native: native) == generated)
	let choices = GameFullscreenResolution.choices(native: native)
	#expect(choices.first == .native)
	#expect(Array(choices.dropFirst().prefix(generated.count)) == generated.map { .fixed($0) })
}

@Test
func sizesLargerThanTheDisplayAreLeftOut() {
	let laptop = GameFullscreenResolution.choices(native: size(2940, 1912))
	#expect(!laptop.contains(.fixed(size(3840, 2160))))
	#expect(laptop.contains(.fixed(size(2560, 1440))))
	#expect(GameFullscreenResolution.choices(native: nil).contains(.fixed(size(3840, 2160))))
}

@Test(arguments: ["native", "5120x2880"])
func fullscreenResolutionsRoundTripTheirStorageValue(value: String) {
	#expect(GameFullscreenResolution(storageValue: value)?.storageValue == value)
}

@Test(arguments: ["", "0x0", "wide", "5120x"])
func malformedFullscreenResolutionsAreRejected(value: String) {
	#expect(GameFullscreenResolution(storageValue: value) == nil)
}

@Test
func onlyWellKnownResolutionsAreNamed() {
	#expect(SettingsStrings.resolutionTitle(size(2560, 1440)) == "2560 × 1440 (WQHD)")
	#expect(SettingsStrings.resolutionTitle(size(1920, 1080)) == "1920 × 1080 (Full HD)")
	#expect(SettingsStrings.resolutionTitle(size(1920, 1200)) == "1920 × 1200")
	#expect(SettingsStrings.resolutionTitle(size(4480, 2520)) == "4480 × 2520")
	#expect(SettingsStrings.nativeResolutionTitle(size(6016, 3384)) == "Native (6016 × 3384)")
	#expect(SettingsStrings.nativeResolutionTitle(nil) == "Native")
}
