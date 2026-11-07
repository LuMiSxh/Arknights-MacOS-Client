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

@Test
func eachLaneOwnsItsWinePrefixName() {
	#expect(RuntimeLane.x86.prefixDirectoryName == "Prefix")
	#expect(RuntimeLane.arm.prefixDirectoryName == "Prefix-ARM64")
	#expect(RuntimeLane.x86.prefixDirectoryName != RuntimeLane.arm.prefixDirectoryName)
}
