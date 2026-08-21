// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func nextResetReturnsTodayWhenBeforeFourAM() {
	let before = ISO8601DateFormatter().date(from: "2026-08-17T02:00:00-07:00")!
	let expected = ISO8601DateFormatter().date(from: "2026-08-17T04:00:00-07:00")!

	#expect(ServerReset.nextReset(for: .global, after: before) == expected)
}

@Test
func nextResetRollsOverToTomorrowWhenAfterFourAM() {
	let after = ISO8601DateFormatter().date(from: "2026-08-17T05:00:00-07:00")!
	let expected = ISO8601DateFormatter().date(from: "2026-08-18T04:00:00-07:00")!

	#expect(ServerReset.nextReset(for: .global, after: after) == expected)
}

@Test
func offsetsMatchEachRegionsFixedServerTime() {
	#expect(ServerReset.offsetSeconds(for: .global) == -7 * 3600)
	#expect(ServerReset.offsetSeconds(for: .japan) == 9 * 3600)
	#expect(ServerReset.offsetSeconds(for: .korea) == 9 * 3600)
}

@Test
func countdownTextFormatsHoursAndMinutes() {
	let now = ISO8601DateFormatter().date(from: "2026-08-17T02:00:00-07:00")!

	#expect(ServerReset.countdownText(for: .global, now: now) == "Reset in 2h 00m")
}
