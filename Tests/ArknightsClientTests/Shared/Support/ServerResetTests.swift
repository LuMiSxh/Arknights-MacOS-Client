// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test(arguments: [
	([GameRegion.global], "2026-08-17T02:00:00-07:00", "2026-08-17T04:00:00-07:00"),
	([GameRegion.global], "2026-08-17T05:00:00-07:00", "2026-08-18T04:00:00-07:00"),
	([GameRegion.china, .chinaBilibili], "2026-08-17T03:00:00+08:00", "2026-08-17T04:00:00+08:00"),
])
func nextResetUsesTheNextFourAM(
	regions: [GameRegion],
	after: String,
	expected: String
) throws {
	let formatter = ISO8601DateFormatter()
	let date = try #require(formatter.date(from: after))
	let expectedDate = try #require(formatter.date(from: expected))

	for region in regions {
		#expect(
			ServerReset.nextReset(for: region, after: date) == expectedDate, "region: \(region)")
	}
}

@Test
func offsetsMatchEachRegionsFixedServerTime() {
	#expect(ServerReset.offsetSeconds(for: .global) == -7 * 3600)
	#expect(ServerReset.offsetSeconds(for: .japan) == 9 * 3600)
	#expect(ServerReset.offsetSeconds(for: .korea) == 9 * 3600)
	#expect(ServerReset.offsetSeconds(for: .taiwan) == 8 * 3600)
	#expect(ServerReset.offsetSeconds(for: .china) == 8 * 3600)
	#expect(ServerReset.offsetSeconds(for: .chinaBilibili) == 8 * 3600)
}

@Test
func countdownTextFormatsHoursAndMinutes() {
	let now = ISO8601DateFormatter().date(from: "2026-08-17T02:00:00-07:00")!

	#expect(
		ServerReset.countdownText(for: .global, now: now)
			== "Reset in 2h 00m"
	)
}
