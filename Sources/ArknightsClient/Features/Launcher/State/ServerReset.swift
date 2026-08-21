// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Arknights servers reset daily at 04:00 server time. Server time is a fixed UTC
/// offset chosen deliberately, not a named timezone, so the reset hour never shifts
/// with daylight saving (confirmed against the Arknights wiki's server-time table).
enum ServerReset {
	static func offsetSeconds(for region: GameRegion) -> Int {
		switch region {
		case .global: -7 * 3600
		case .japan, .korea: 9 * 3600
		}
	}

	static func nextReset(for region: GameRegion, after date: Date = Date()) -> Date {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: offsetSeconds(for: region))!
		var components = calendar.dateComponents([.year, .month, .day], from: date)
		components.hour = 4
		components.minute = 0
		components.second = 0
		let todayReset = calendar.date(from: components)!
		return todayReset > date
			? todayReset : calendar.date(byAdding: .day, value: 1, to: todayReset)!
	}

	static func countdownText(for region: GameRegion, now: Date = Date()) -> String {
		let remaining = max(0, Int(nextReset(for: region, after: now).timeIntervalSince(now)))
		return String(format: "Reset in %dh %02dm", remaining / 3600, (remaining % 3600) / 60)
	}
}
