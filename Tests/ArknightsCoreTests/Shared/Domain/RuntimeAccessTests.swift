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
	@Test
	func x86IsDeniedOnMacOS28AndLater() {
		#expect(!access(macOS: 28).allows(.x86))
		#expect(!access(macOS: 29).allows(.x86))
	}

	@Test
	func armIsDeniedBeforeMacOS26() {
		#expect(!access(macOS: 15).allows(.arm))
		#expect(!access(macOS: 25).allows(.arm))
	}

}
