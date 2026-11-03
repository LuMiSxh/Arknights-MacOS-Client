// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

/// The reminders that should be pending for one moment, derived from preferences alone.
enum ResetReminderPlan {
	/// Returns one notification per upcoming reset, soonest first, capped at the pending limit.
	/// A fire time that is already past is skipped, never scheduled late.
	static func notifications(
		now: Date,
		timing: ResetReminderTiming,
		regions: [GameRegion],
		windowDays: Int = AppConstants.Reminders.rollingWindowDays,
		limit: Int = AppConstants.Reminders.maximumPendingRequests
	) -> [LocalNotification] {
		guard let lead = timing.leadMinutes else { return [] }
		var notifications: [(fireDate: Date, notification: LocalNotification)] = []
		for region in regions {
			var reset = region.dailyReset(after: now)
			for _ in 0..<windowDays {
				let fireDate = reset.addingTimeInterval(-Double(lead) * 60)
				if fireDate > now {
					notifications.append(
						(
							fireDate,
							LocalNotification(
								identifier: identifier(region: region, reset: reset, lead: lead),
								title: "Arknights \(region.displayName)",
								body: body(timing: timing),
								trigger: .calendar(utcComponents(for: fireDate))
							)
						))
				}
				reset = region.dailyReset(after: reset)
			}
		}
		return
			notifications
			.sorted {
				($0.fireDate, $0.notification.identifier) < (
					$1.fireDate, $1.notification.identifier
				)
			}
			.prefix(limit)
			.map(\.notification)
	}

	/// `reset.<region>.<yyyy-MM-dd>.<lead minutes>` where the date is the server date of the reset.
	/// The lead is part of the ID so a changed timing replaces requests instead of keeping them.
	static func identifier(region: GameRegion, reset: Date, lead: Int) -> String {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = region.serverTimeZone
		let day = calendar.dateComponents([.year, .month, .day], from: reset)
		return AppConstants.Reminders.identifierPrefix + region.rawValue
			+ String(
				format: ".%04d-%02d-%02d.%d", day.year ?? 0, day.month ?? 0, day.day ?? 0, lead)
	}

	// The body names no local time: a request built before a daylight-saving switch would keep
	// a stale time, and the ID diff would not replace it.
	private static func body(timing: ResetReminderTiming) -> String {
		switch timing {
		case .off, .atReset: "The daily reset is here."
		case .minutes15: "Daily reset in 15 minutes (04:00 server time)."
		case .minutes30: "Daily reset in 30 minutes (04:00 server time)."
		case .minutes60: "Daily reset in 1 hour (04:00 server time)."
		case .minutes120: "Daily reset in 2 hours (04:00 server time)."
		}
	}

	/// Absolute UTC components, so the trigger fires at one instant wherever the Mac is.
	private static func utcComponents(for date: Date) -> DateComponents {
		var calendar = Calendar(identifier: .gregorian)
		let utc = TimeZone(secondsFromGMT: 0)!
		calendar.timeZone = utc
		var components = calendar.dateComponents(
			[.year, .month, .day, .hour, .minute, .second], from: date)
		components.calendar = calendar
		components.timeZone = utc
		return components
	}
}
