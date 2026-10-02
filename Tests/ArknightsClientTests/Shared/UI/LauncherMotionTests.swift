// SPDX-License-Identifier: MPL-2.0

import SwiftUI
import Testing

@testable import ArknightsClient

private let allCurves: [LauncherMotion.Curve] = [
	.press, .release, .hover, .state, .morph, .expansion, .reveal, .present, .dismiss,
	.crossfade,
]

@Test(arguments: allCurves)
func launcherMotionRemovesEveryCurveUnderReduceMotion(curve: LauncherMotion.Curve) {
	#expect(LauncherMotion.animation(curve, reduceMotion: true) == nil)
	#expect(LauncherMotion.animation(curve, reduceMotion: false) == curve.animation)
	#expect(LauncherMotion.staggered(curve, index: 2, reduceMotion: true) == nil)
}

@Test
func launcherMotionStaggersSiblingsByIndex() {
	let step = LauncherMotion.staggerStep
	#expect(
		LauncherMotion.staggered(.state, index: 0, reduceMotion: false)
			== LauncherMotion.Curve.state.animation.delay(0)
	)
	#expect(
		LauncherMotion.staggered(.state, index: 2, reduceMotion: false)
			== LauncherMotion.Curve.state.animation.delay(step * 2)
	)
	#expect(
		LauncherMotion.staggered(.state, index: -1, reduceMotion: false)
			== LauncherMotion.Curve.state.animation.delay(0)
	)
}

@Test
func launcherMotionFadeStaysVisibleUnderReduceMotion() {
	#expect(LauncherMotion.fade(reduceMotion: true) == .easeInOut(duration: 0.15))
	#expect(LauncherMotion.fade(reduceMotion: false) == LauncherMotion.Curve.state.animation)
}
