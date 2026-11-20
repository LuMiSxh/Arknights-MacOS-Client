// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

private func access(macOS major: Int, _ minor: Int = 0) -> RuntimeAccess {
	RuntimeAccess(
		macOSVersion: OperatingSystemVersion(
			majorVersion: major, minorVersion: minor, patchVersion: 0)
	)
}

struct RuntimeAccessTests {
	@Test(arguments: [
		(major: 27, minor: 0, lane: RuntimeLane.x86, allows: true),
		(major: 28, minor: 0, lane: .x86, allows: false),
		(major: 15, minor: 0, lane: .arm, allows: false),
		(major: 26, minor: 5, lane: .arm, allows: false),
		(major: 27, minor: 0, lane: .arm, allows: true),
	])
	func accessFollowsTheLaneMacOSBounds(major: Int, minor: Int, lane: RuntimeLane, allows: Bool) {
		#expect(access(macOS: major, minor).allows(lane) == allows)
	}

	@Test(arguments: [
		(major: 15, expected: RuntimeLane.x86),
		(major: 26, expected: .x86),
		(major: 27, expected: .arm),
		(major: 28, expected: .arm),
	])
	func theDefaultLaneIsARMOnlyWhereARMIsAllowed(major: Int, expected: RuntimeLane) {
		#expect(access(macOS: major).defaultLane == expected)
	}
}
