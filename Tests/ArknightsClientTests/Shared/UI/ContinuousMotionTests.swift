// SPDX-License-Identifier: MPL-2.0

import Foundation
import SwiftUI
import Testing

@testable import ArknightsClient

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

@Test
func continuousMotionReducedPhaseOverridesOnlyUnderReduceMotion() {
	typealias Motion = ContinuousMotion<EmptyView>
	#expect(Motion.pausedPhase(reduceMotion: true, reducedMotionPhase: 0.5, clockPhase: 0.2) == 0.5)
	#expect(Motion.pausedPhase(reduceMotion: true, reducedMotionPhase: nil, clockPhase: 0.2) == 0.2)
	#expect(
		Motion.pausedPhase(reduceMotion: false, reducedMotionPhase: 0.5, clockPhase: 0.2) == 0.2)
}

@Test
func continuousMotionClockWrapsPausesAndResumesPhase() {
	var clock = DecorativeMotionClock()
	let start = Date(timeIntervalSinceReferenceDate: 1000)
	clock.begin(at: start, cycleDuration: 4)
	#expect(clock.phase(at: start.addingTimeInterval(1), cycleDuration: 4) == 0.25)
	#expect(clock.phase(at: start.addingTimeInterval(5), cycleDuration: 4) == 0.25)

	clock.pause(at: start.addingTimeInterval(2), cycleDuration: 4)
	#expect(clock.pausedPhase == 0.5)
	#expect(clock.phase(at: start.addingTimeInterval(100), cycleDuration: 4) == 0.5)

	let resumed = start.addingTimeInterval(100)
	clock.resume(at: resumed, cycleDuration: 4)
	#expect(clock.phase(at: resumed.addingTimeInterval(1), cycleDuration: 4) == 0.75)
}
