// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsGameRuntime

// Refresh rate, requested cap, and the cap DXMT receives.
@Test(arguments: [
	(60, 30, 30), (60, 60, 60), (60, 120, 120),
	(120, 30, 30), (120, 60, 60), (120, 120, 120),
	(144, 30, 24), (144, 60, 48), (144, 120, 144),
	(165, 30, 33), (165, 60, 55), (165, 120, 165),
	(0, 30, 30), (0, 60, 60), (0, 120, 120),
])
func dxmtFrameRateCapDividesDisplayRefreshRate(
	refreshRate: Int, requested: Int, expected: Int
) {
	#expect(
		WineRuntime.dxmtFrameRateCap(requested: requested, displayRefreshRate: refreshRate)
			== expected)
}
