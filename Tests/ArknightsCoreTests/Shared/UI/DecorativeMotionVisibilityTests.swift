// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Testing

@testable import ArknightsCore

@Test
@MainActor
func decorativeMotionVisibilityStopsWhileAttachedToAnUnshownWindow() {
	let subject = DecorativeMotionVisibility(
		notificationCenter: NotificationCenter(),
		lowPowerModeProvider: { false }
	)
	let window = NSWindow(
		contentRect: .zero,
		styleMask: .borderless,
		backing: .buffered,
		defer: true
	)
	#expect(subject.isEnabled)

	subject.attach(to: window)
	#expect(!subject.isEnabled)

	subject.detach()
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
@MainActor
func decorativeMotionVisibilityTracksGameActivity() {
	let subject = DecorativeMotionVisibility(
		notificationCenter: NotificationCenter(),
		lowPowerModeProvider: { false }
	)
	subject.setGameActive(true)
	#expect(!subject.isEnabled)
	subject.setGameActive(false)
	#expect(subject.isEnabled)
}

@Test
@MainActor
func decorativeMotionVisibilityFollowsPowerStateNotifications() {
	let center = NotificationCenter()
	nonisolated(unsafe) var lowPower = false
	let subject = DecorativeMotionVisibility(
		notificationCenter: center,
		lowPowerModeProvider: { lowPower }
	)
	let window = NSWindow(
		contentRect: .zero,
		styleMask: .borderless,
		backing: .buffered,
		defer: true
	)
	subject.attach(to: window)

	lowPower = true
	center.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
	#expect(subject.isLowPowerModeEnabled)
	#expect(!subject.isEnabled)

	subject.detach()
	lowPower = false
	center.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
	#expect(subject.isLowPowerModeEnabled)
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
