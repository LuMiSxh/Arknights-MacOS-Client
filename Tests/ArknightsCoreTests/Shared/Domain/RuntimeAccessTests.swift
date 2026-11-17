// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

private func access(macOS major: Int) -> RuntimeAccess {
	RuntimeAccess(
		macOSVersion: OperatingSystemVersion(majorVersion: major, minorVersion: 0, patchVersion: 0)
	)
}

struct RuntimeAccessTests {
	@Test(arguments: [
		(major: 27, lane: RuntimeLane.x86, allows: true),
		(major: 28, lane: .x86, allows: false),
		(major: 29, lane: .x86, allows: false),
		(major: 15, lane: .arm, allows: false),
		(major: 25, lane: .arm, allows: false),
		(major: 26, lane: .arm, allows: true),
	])
	func accessFollowsTheLaneMacOSBounds(major: Int, lane: RuntimeLane, allows: Bool) {
		#expect(access(macOS: major).allows(lane) == allows)
	}
}
