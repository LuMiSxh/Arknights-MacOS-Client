// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

@Test
func lanesUseDistinctPersistedNames() {
	#expect(RuntimeLane(rawValue: "x86") == .x86)
	#expect(RuntimeLane(rawValue: "arm") == .arm)
	#expect(RuntimeLane(rawValue: "aarch64") == nil)
	#expect(RuntimeLane.allCases == [.x86, .arm])
}
