// SPDX-License-Identifier: MPL-2.0

import Foundation

struct PlaytimeStatistics: Codable, Equatable, Sendable {
	struct Session: Codable, Equatable, Sendable {
		let region: GameRegion
		let startedAt: Date
		let duration: TimeInterval
	}

	struct ActiveSession: Codable, Equatable, Sendable {
		let id: UUID
		let region: GameRegion
		let startedAt: Date
	}

	struct Day: Codable, Equatable, Sendable {
		let date: Date
		var durations: [GameRegion: TimeInterval]
	}

	var version = AppConstants.Playtime.schemaVersion
	var totals: [GameRegion: TimeInterval] = [:]
	var days: [Day] = []
	var latestSession: Session?
	var activeSession: ActiveSession?

	static let empty = PlaytimeStatistics()

	var totalDuration: TimeInterval {
		totals.values.reduce(0, +)
	}

	func duration(for region: GameRegion) -> TimeInterval {
		totals[region, default: 0]
	}

	func duration(
		inLast dayCount: Int,
		now: Date,
		calendar: Calendar
	) -> TimeInterval {
		guard dayCount > 0 else { return 0 }
		let today = calendar.startOfDay(for: now)
		guard
			let firstDay = calendar.date(byAdding: .day, value: 1 - dayCount, to: today),
			let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
		else { return 0 }
		return days.lazy
			.filter { $0.date >= firstDay && $0.date < tomorrow }
			.flatMap(\.durations.values)
			.reduce(0, +)
	}

	mutating func record(
		region: GameRegion,
		startedAt: Date,
		duration: TimeInterval,
		calendar: Calendar
	) {
		let safeDuration = max(0, duration)
		totals[region, default: 0] += safeDuration
		latestSession = Session(
			region: region,
			startedAt: startedAt,
			duration: safeDuration
		)

		let day = calendar.startOfDay(for: startedAt)
		if let index = days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
			days[index].durations[region, default: 0] += safeDuration
		} else {
			days.append(Day(date: day, durations: [region: safeDuration]))
		}
		days.sort { $0.date > $1.date }
		if days.count > AppConstants.Playtime.dailyHistoryLimit {
			days.removeLast(days.count - AppConstants.Playtime.dailyHistoryLimit)
		}
	}

	func validated() throws -> Self {
		guard version == AppConstants.Playtime.schemaVersion else {
			throw PlaytimeStatisticsError.unsupportedVersion(version)
		}
		guard days.count <= AppConstants.Playtime.dailyHistoryLimit else {
			throw PlaytimeStatisticsError.invalidData
		}
		let durations =
			Array(totals.values)
			+ days.flatMap { Array($0.durations.values) }
			+ [latestSession?.duration].compactMap { $0 }
		guard durations.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
			throw PlaytimeStatisticsError.invalidData
		}
		let dates =
			days.map(\.date)
			+ [latestSession?.startedAt, activeSession?.startedAt]
			.compactMap { $0 }
		guard dates.allSatisfy({ $0.timeIntervalSinceReferenceDate.isFinite }) else {
			throw PlaytimeStatisticsError.invalidData
		}
		return self
	}
}

enum PlaytimeStatisticsError: LocalizedError {
	case fileTooLarge
	case invalidData
	case unsupportedVersion(Int)

	var errorDescription: String? {
		switch self {
		case .fileTooLarge: "Playtime statistics exceed the supported file size."
		case .invalidData: "Playtime statistics contain invalid data."
		case .unsupportedVersion(let version):
			"Playtime statistics use unsupported schema version \(version)."
		}
	}
}
