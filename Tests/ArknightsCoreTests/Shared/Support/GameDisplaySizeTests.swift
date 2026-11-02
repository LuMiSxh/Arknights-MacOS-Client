// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsCore

@Test(arguments: [
	// Below the minimum width or height.
	(639, 360, false),
	(640, 359, false),
	// Above the maximum on either axis.
	(8193, 720, false),
	(1280, 8193, false),
	// Valid, including both limits.
	(640, 360, true),
	(8192, 8192, true),
	(1280, 720, true),
])
func customWindowSizesAcceptOnlyWholeSizesWithinTheLimits(
	width: Int, height: Int, isAccepted: Bool
) {
	#expect((GameDisplaySize.validatedCustom(width: width, height: height) != nil) == isAccepted)
}
