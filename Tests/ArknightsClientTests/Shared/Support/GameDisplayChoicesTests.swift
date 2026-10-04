// SPDX-License-Identifier: MPL-2.0

import CoreGraphics
import Testing

@testable import ArknightsClient

private func screen(_ width: Double, _ height: Double, titleBar: Double = 28)
	-> GameScreenMetrics
{
	GameScreenMetrics(
		visibleSize: CGSize(width: width, height: height),
		pixelSize: CGSize(width: width * 2, height: height * 2),
		titleBarHeight: titleBar
	)
}

private func size(_ width: Int, _ height: Int) -> GameDisplaySize {
	GameDisplaySize(width: width, height: height)
}

@Test(arguments: [
	(screen(1470, 919), size(1470, 891), size(960, 540)),
	(screen(3008, 1659), size(3008, 1631), size(1600, 900)),
	(screen(1920, 1055, titleBar: 32), size(1920, 1023), size(1152, 648)),
	(screen(400, 300), size(400, 320), size(960, 540)),
	(screen(30_000, 20_000), size(16_384, 16_384), size(3840, 2160)),
])
func windowSizeChoicesFillTheScreenOrLeaveRoom(
	display: GameScreenMetrics, fill: GameDisplaySize, room: GameDisplaySize
) {
	#expect(GameWindowSizeChoice.fillScreen.size(on: display) == fill)
	#expect(GameWindowSizeChoice.leaveRoom.size(on: display) == room)
}

@Test(arguments: [screen(3008, 1659), screen(1920, 1055), screen(2560, 1400)])
func leaveRoomStaysWidescreenWithinTheScreenShare(display: GameScreenMetrics) {
	let room = GameWindowSizeChoice.leaveRoom.size(on: display)
	let share = AppConstants.Game.compactWindowScreenShare

	#expect(room.width * 9 == room.height * 16)
	#expect(Double(room.width) <= display.visibleSize.width * share)
	#expect(Double(room.height) <= display.visibleSize.height * share)
}

@Test(arguments: [screen(1470, 919), screen(3008, 1659)], GameWindowSizeChoice.allCases)
func windowSizeChoicesAreReadBackFromTheirSize(
	display: GameScreenMetrics, choice: GameWindowSizeChoice
) {
	#expect(GameWindowSizeChoice.matching(choice.size(on: display), on: display) == choice)
}

@Test
func customWindowSizesMatchNoChoice() {
	#expect(GameWindowSizeChoice.matching(size(1280, 720), on: screen(1470, 919)) == nil)
}

@Test(arguments: [
	(size(1920, 1080), size(1920, 1080), [GameFullscreenDetail.full]),
	(size(2560, 1440), size(2560, 1440), [.full, .lighter]),
	(size(3840, 2160), size(2560, 1440), [.full, .balanced, .lighter]),
	(size(3024, 1964), size(2560, 1440), [.full, .balanced, .lighter]),
	(size(1366, 768), size(1360, 768), [.full, .balanced]),
])
func fullscreenDetailMapsToResolutionsOnEachDisplay(
	native: GameDisplaySize, balanced: GameDisplaySize, available: [GameFullscreenDetail]
) {
	#expect(GameFullscreenDetail.full.resolution(native: native) == .native)
	#expect(GameFullscreenDetail.lighter.resolution(native: native) == .fixed(size(1920, 1080)))
	if available.contains(.balanced) {
		#expect(GameFullscreenDetail.balanced.resolution(native: native) == .fixed(balanced))
	}
	#expect(GameFullscreenDetail.available(native: native) == available)
}

@Test
func fullscreenDetailWithoutAKnownDisplayStillOffersEveryLevel() {
	#expect(GameFullscreenDetail.balanced.resolution(native: nil) == .fixed(size(2560, 1440)))
	#expect(GameFullscreenDetail.available(native: nil) == GameFullscreenDetail.allCases)
}

@Test(arguments: [size(1920, 1080), size(2560, 1440), size(3840, 2160), size(3024, 1964)])
func fullscreenDetailIsReadBackFromItsResolution(native: GameDisplaySize) {
	for detail in GameFullscreenDetail.available(native: native) {
		#expect(
			GameFullscreenDetail.matching(detail.resolution(native: native), native: native)
				== detail)
	}
	#expect(GameFullscreenDetail.matching(.fixed(size(1280, 720)), native: native) == nil)
}
