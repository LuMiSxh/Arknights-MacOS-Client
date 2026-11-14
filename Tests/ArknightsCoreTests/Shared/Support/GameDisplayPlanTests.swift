// SPDX-License-Identifier: MPL-2.0

import CoreGraphics
import Testing

@testable import ArknightsCore

private func size(_ width: Int, _ height: Int) -> GameDisplaySize {
	GameDisplaySize(width: width, height: height)
}

@Test
func nativeSpaceContentExcludesTheNotchFromTheFullscreenHeight() {
	let display = GameFullscreenDisplay(
		pointSize: size(1512, 982), backingScale: 2, notchHeight: 32)

	#expect(display.nativeSpaceContent.pixelSize == size(3024, 1900))
}
