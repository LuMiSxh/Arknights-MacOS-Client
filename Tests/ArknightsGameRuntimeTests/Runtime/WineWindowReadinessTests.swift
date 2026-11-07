// SPDX-License-Identifier: MPL-2.0

import CoreGraphics
import Darwin
import Foundation
import Testing

@testable import ArknightsGameRuntime

@Test
private func convertsThePidCountFromProcListChildPids() {
	let buffer: [pid_t] = [42, 43, 0, 0]
	#expect(
		WineWindowReadiness.childIdentifiers(
			listed: 2, buffer: buffer, capacity: 4
		) == [42, 43]
	)
}

@Test
private func acceptsTheGameWindowOfALaunchedProcessChild() {
	let gamePID: Int32 = 42
	let windows: [[String: Any]] = [
		[
			kCGWindowOwnerPID as String: NSNumber(value: gamePID),
			kCGWindowNumber as String: NSNumber(value: 7),
			kCGWindowLayer as String: NSNumber(value: 0),
			kCGWindowIsOnscreen as String: NSNumber(value: true),
			kCGWindowAlpha as String: NSNumber(value: 1),
			kCGWindowBounds as String: [
				"Width": NSNumber(value: 1280),
				"Height": NSNumber(value: 720),
			],
		]
	]

	#expect(
		WineWindowReadiness.isVisible(
			processIdentifier: 1, windows: windows, descendantIdentifiers: [gamePID]))
	#expect(
		!WineWindowReadiness.isVisible(
			processIdentifier: 1, windows: windows, descendantIdentifiers: []))
}
