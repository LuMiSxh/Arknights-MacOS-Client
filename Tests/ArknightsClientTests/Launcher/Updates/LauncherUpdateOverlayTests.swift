// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func updateOverlayRequiresTheUpdateDestinationAndVisibleDriver() {
	#expect(
		LauncherUpdateOverlayPresentation.isPresented(
			destination: .update,
			driverIsPresented: true))
	#expect(
		!LauncherUpdateOverlayPresentation.isPresented(
			destination: .settings,
			driverIsPresented: true))
	#expect(
		!LauncherUpdateOverlayPresentation.isPresented(
			destination: .update,
			driverIsPresented: false))
}

@Test
func updateOverlayMotionKeepsDialogAndDimDurationsSeparate() {
	let motion = LauncherUpdateOverlayPresentation.motion(reduceMotion: false)

	#expect(
		motion
			== .animated(
				backgroundDuration: 0.18,
				dialogDuration: 0.22,
				initialDialogScale: 0.985))
	#expect(LauncherUpdateOverlayPresentation.motion(reduceMotion: true) == .immediate)
}

@Test
@MainActor
func updateOverlayDismissalCancelsAnActiveCheckImmediately() {
	let driver = LauncherUpdateUserDriver()
	var cancellationCount = 0
	driver.showUserInitiatedUpdateCheck { cancellationCount += 1 }

	driver.dismissFromUser()

	#expect(cancellationCount == 1)
	#expect(driver.phase == .hidden)
	#expect(!driver.isPresented)
}
