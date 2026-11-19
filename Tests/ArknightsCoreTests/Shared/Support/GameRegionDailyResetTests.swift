// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

private struct DailyResetExample: Sendable, CustomTestStringConvertible {
	let region: GameRegion
	let now: Date
	let expected: Date

	var testDescription: String { "\(region.rawValue) after \(now)" }
}

private func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
	var calendar = Calendar(identifier: .gregorian)
	calendar.timeZone = TimeZone(identifier: "UTC")!
	return calendar.date(
		from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

// Expected values are UTC instants. Europe/Berlin changes offset at 01:00 UTC on 2026-03-29
// and 2026-10-25. A Berlin user sees the Global reset move from 12:00 CET to 13:00 CEST, but
// the instant stays at 11:00 UTC.
@Test(arguments: [
	DailyResetExample(region: .global, now: utc(2026, 11, 3, 10), expected: utc(2026, 11, 3, 11)),
	DailyResetExample(region: .global, now: utc(2026, 7, 1, 10), expected: utc(2026, 7, 1, 11)),
	DailyResetExample(region: .japan, now: utc(2026, 11, 3, 10), expected: utc(2026, 11, 3, 19)),
	DailyResetExample(region: .korea, now: utc(2026, 11, 3, 10), expected: utc(2026, 11, 3, 19)),
	DailyResetExample(region: .taiwan, now: utc(2026, 11, 3, 10), expected: utc(2026, 11, 3, 20)),
	DailyResetExample(region: .china, now: utc(2026, 11, 3, 10), expected: utc(2026, 11, 3, 20)),
	DailyResetExample(
		region: .chinaBilibili, now: utc(2026, 11, 3, 10), expected: utc(2026, 11, 3, 20)),
	// Exactly at a reset, the next reset is one day later.
	DailyResetExample(region: .global, now: utc(2026, 11, 3, 11), expected: utc(2026, 11, 4, 11)),
	DailyResetExample(region: .japan, now: utc(2026, 11, 3, 19), expected: utc(2026, 11, 4, 19)),
	DailyResetExample(
		region: .global, now: utc(2026, 11, 3, 10, 59), expected: utc(2026, 11, 3, 11)),
	// Berlin summer time starts on 2026-03-29. Berlin summer time ends on 2026-10-25.
	DailyResetExample(region: .global, now: utc(2026, 3, 28, 11), expected: utc(2026, 3, 29, 11)),
	DailyResetExample(region: .global, now: utc(2026, 10, 24, 11), expected: utc(2026, 10, 25, 11)),
])
private func dailyResetIsTheNextFourAMServerTimeStrictlyAfterNow(example: DailyResetExample) {
	#expect(example.region.dailyReset(after: example.now) == example.expected)
}
