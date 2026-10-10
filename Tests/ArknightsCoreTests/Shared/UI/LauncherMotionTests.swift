// SPDX-License-Identifier: MPL-2.0

import SwiftUI
import Testing

@testable import ArknightsCore

private let allCurves: [LauncherMotion.Curve] = [
	.press, .release, .hover, .state, .morph, .present, .dismiss, .crossfade,
	.select, .page, .progress, .backdrop, .ripple, .settle, .disclosure,
]

@Test(arguments: allCurves)
func launcherMotionRemovesEveryCurveUnderReduceMotion(curve: LauncherMotion.Curve) {
	#expect(LauncherMotion.animation(curve, reduceMotion: true) == nil)
	#expect(LauncherMotion.animation(curve, reduceMotion: false) == curve.animation)
	#expect(LauncherMotion.staggered(curve, index: 2, reduceMotion: true) == nil)
}

@Test
func launcherMotionNewCurvesKeepExactValues() {
	#expect(LauncherMotion.Curve.select.animation == .easeInOut(duration: 0.16))
	#expect(LauncherMotion.Curve.page.animation == .easeInOut(duration: 0.22))
	#expect(LauncherMotion.Curve.progress.animation == .linear(duration: 0.20))
	#expect(LauncherMotion.Curve.backdrop.animation == .easeOut(duration: 0.24))
	#expect(LauncherMotion.Curve.ripple.animation == .easeOut(duration: 0.9))
	#expect(LauncherMotion.Curve.settle.animation == .easeIn(duration: 0.18))
	#expect(LauncherMotion.Curve.disclosure.animation == .snappy(duration: 0.3, extraBounce: 0))
}

@Test
func launcherMotionMergedCurvesAreGone() {
	let names = Set(allCurves.map { String(describing: $0) })
	#expect(!names.contains("reveal"))
	#expect(!names.contains("expansion"))
	#expect(names.count == 15)
}

@Test
func launcherMotionCycleKeepsExactValues() {
	typealias Cycle = LauncherMotion.Cycle
	#expect(Cycle.breathing == 3.2)
	#expect(Cycle.completionFeedback == .milliseconds(400))
	#expect(Cycle.progressSweepFadeIn == 0.12)
	#expect(Cycle.progressSweepTravel == 1.40)
	#expect(Cycle.progressSweepFadeOut == 0.25)
	#expect(Cycle.progressSweepPause == 0.55)
	#expect(Cycle.indeterminateOrbitLaps == 2.0)
	#expect(Cycle.indeterminateGlintLength == 0.14)
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
