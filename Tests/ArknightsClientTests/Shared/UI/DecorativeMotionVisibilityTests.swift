// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Testing

@testable import ArknightsClient

@Test
func decorativeMotionRequiresAnActiveVisibleUnoccludedWindow() {
	#expect(
		DecorativeMotionVisibilityPolicy.isEnabled(
			applicationIsActive: true,
			applicationIsHidden: false,
			windowIsVisible: true,
			windowIsMiniaturized: false,
			windowIsOccluded: false
		)
	)
	#expect(
		!DecorativeMotionVisibilityPolicy.isEnabled(
			applicationIsActive: false,
			applicationIsHidden: false,
			windowIsVisible: true,
			windowIsMiniaturized: false,
			windowIsOccluded: false
		)
	)
	#expect(
		!DecorativeMotionVisibilityPolicy.isEnabled(
			applicationIsActive: true,
			applicationIsHidden: false,
			windowIsVisible: true,
			windowIsMiniaturized: true,
			windowIsOccluded: false
		)
	)
	#expect(
		!DecorativeMotionVisibilityPolicy.isEnabled(
			applicationIsActive: true,
			applicationIsHidden: false,
			windowIsVisible: true,
			windowIsMiniaturized: false,
			windowIsOccluded: true
		)
	)
	#expect(
		!DecorativeMotionVisibilityPolicy.isEnabled(
			applicationIsActive: true,
			applicationIsHidden: true,
			windowIsVisible: true,
			windowIsMiniaturized: false,
			windowIsOccluded: false
		)
	)
}

@Test
@MainActor
func decorativeMotionVisibilityStopsAndResumesWithWindowState() {
	let subject = DecorativeMotionVisibility(notificationCenter: NotificationCenter())

	subject.update(
		applicationIsActive: true,
		applicationIsHidden: false,
		windowIsVisible: true,
		windowIsMiniaturized: false,
		windowIsOccluded: false
	)
	#expect(subject.isEnabled)

	subject.update(
		applicationIsActive: true,
		applicationIsHidden: false,
		windowIsVisible: true,
		windowIsMiniaturized: false,
		windowIsOccluded: true
	)
	#expect(!subject.isEnabled)

	subject.update(
		applicationIsActive: true,
		applicationIsHidden: false,
		windowIsVisible: true,
		windowIsMiniaturized: false,
		windowIsOccluded: false
	)
	#expect(subject.isEnabled)
}

@Test
@MainActor
func decorativeMotionVisibilityRemovesObserversWhenDetached() {
	let subject = DecorativeMotionVisibility(notificationCenter: NotificationCenter())
	let window = NSWindow(
		contentRect: .zero,
		styleMask: .borderless,
		backing: .buffered,
		defer: true
	)

	subject.attach(to: window)
	#expect(subject.isObserving)

	subject.detach()
	#expect(!subject.isObserving)
}

@Test
func decorativeMotionClockPreservesItsPhaseAcrossAVisibilityPause() {
	var clock = DecorativeMotionClock()
	let start = Date(timeIntervalSince1970: 100)
	clock.begin(at: start, cycleDuration: 10)

	let phaseBeforePause = clock.phase(at: start.addingTimeInterval(3), cycleDuration: 10)
	clock.pause(at: start.addingTimeInterval(3), cycleDuration: 10)
	clock.resume(at: start.addingTimeInterval(100), cycleDuration: 10)
	let phaseAfterResume = clock.phase(
		at: start.addingTimeInterval(101),
		cycleDuration: 10
	)

	#expect(abs(phaseBeforePause - 0.3) < 0.001)
	#expect(abs(phaseAfterResume - 0.4) < 0.001)
}
