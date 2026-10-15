// SPDX-License-Identifier: MPL-2.0

import SwiftUI
import Testing

@testable import ArknightsCore

@Test(arguments: [
	(true, false, true),
	(true, true, false),
	(false, false, false),
	(false, true, false),
])
func continuousMotionAnimatesOnlyWhenVisibleAndNotReduced(
	enabled: Bool, reduce: Bool, expected: Bool
) {
	#expect(
		ContinuousMotion<EmptyView>.isAnimating(
			decorativeMotionEnabled: enabled, reduceMotion: reduce) == expected)
}
