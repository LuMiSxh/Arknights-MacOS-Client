// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Testing

@testable import ArknightsCore

@Test
@MainActor
func decorativeMotionStopsWhileTheGameIsActiveOrLowPowerModeIsOn() {
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
	#expect(subject.isEnabled)

	// A window that is attached but not shown counts as hidden.
	subject.attach(to: window)
	#expect(!subject.isEnabled)
	subject.detach()
	#expect(subject.isEnabled)

	subject.setGameActive(true)
	#expect(!subject.isEnabled)
	subject.setGameActive(false)
	#expect(subject.isEnabled)

	subject.attach(to: window)
	lowPower = true
	center.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
	#expect(subject.isLowPowerModeEnabled)
	#expect(!subject.isEnabled)
}
