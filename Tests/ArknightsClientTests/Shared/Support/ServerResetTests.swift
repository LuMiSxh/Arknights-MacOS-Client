// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test(arguments: [
	("2026-08-17T02:00:00-07:00", "2026-08-17T04:00:00-07:00"),
	("2026-08-17T05:00:00-07:00", "2026-08-18T04:00:00-07:00"),
])
func nextResetUsesTheNextFourAM(after: String, expected: String) throws {
	let formatter = ISO8601DateFormatter()
	let date = try #require(formatter.date(from: after))
	let expectedDate = try #require(formatter.date(from: expected))

	#expect(ServerReset.nextReset(for: .global, after: date) == expectedDate)
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

	#expect(
		ServerReset.countdownText(for: .global, now: now, locale: Locale(identifier: "en"))
			== "Reset in 2h 00m"
	)
	#expect(
		ServerReset.countdownText(for: .global, now: now, locale: Locale(identifier: "de"))
			== "Reset in 2 Std. 00 Min."
	)
}
