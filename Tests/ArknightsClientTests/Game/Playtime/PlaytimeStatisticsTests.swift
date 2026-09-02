// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct PlaytimeStatisticsTests {
	@Test
	func visibleSessionUsesMonotonicTimeAndRecordsOnlyOnce() throws {
		let fixture = try Fixture()
		var wallClock = fixture.date(2026, 1, 31, hour: 23)
		var uptime: TimeInterval = 1_000
		let controller = fixture.controller(now: { wallClock }, uptime: { uptime })
		let sessionID = UUID()

		controller.start(sessionID: sessionID, region: .global)
		wallClock = fixture.date(2026, 2, 2, hour: 8)
		uptime += 90

		#expect(controller.finish(sessionID: sessionID) == 90)
		#expect(controller.finish(sessionID: sessionID) == nil)
		#expect(
			controller.statistics.latestSession?.startedAt == fixture.date(2026, 1, 31, hour: 23))
		#expect(controller.statistics.days.first?.date == fixture.date(2026, 1, 31))
	}

	@Test
	func totalsStayIndependentAcrossRegionsAndReloads() throws {
		let fixture = try Fixture()
		var uptime: TimeInterval = 0
		let controller = fixture.controller(now: { fixture.date(2026, 3, 1) }, uptime: { uptime })

		for (region, duration) in zip(GameRegion.allCases, [60.0, 120.0, 180.0, 240.0, 300.0]) {
			let sessionID = UUID()
			controller.start(sessionID: sessionID, region: region)
			uptime += duration
			controller.finish(sessionID: sessionID)
		}

		let reloaded = fixture.controller()
		#expect(reloaded.totalDuration == 900)
		#expect(reloaded.duration(for: .global) == 60)
		#expect(reloaded.duration(for: .japan) == 120)
		#expect(reloaded.duration(for: .korea) == 180)
		#expect(reloaded.duration(for: .china) == 240)
		#expect(reloaded.duration(for: .chinaBilibili) == 300)
		#expect(reloaded.statistics.latestSession?.region == .chinaBilibili)
	}

	@Test
	func recentSummariesRespectCalendarBoundariesInEnglishAndGerman() throws {
		let fixture = try Fixture()
		var statistics = PlaytimeStatistics.empty
		let now = fixture.date(2026, 1, 30, hour: 12)
		statistics.record(
			region: .global,
			startedAt: fixture.date(2025, 12, 31, hour: 23),
			duration: 30,
			calendar: fixture.calendar
		)
		statistics.record(
			region: .japan,
			startedAt: fixture.date(2026, 1, 1),
			duration: 60,
			calendar: fixture.calendar
		)
		statistics.record(
			region: .korea,
			startedAt: fixture.date(2026, 1, 29),
			duration: 90,
			calendar: fixture.calendar
		)

		for localeIdentifier in ["en_US", "de_DE"] {
			var calendar = fixture.calendar
			calendar.locale = Locale(identifier: localeIdentifier)
			#expect(statistics.duration(inLast: 7, now: now, calendar: calendar) == 90)
			#expect(statistics.duration(inLast: 30, now: now, calendar: calendar) == 150)
		}
	}

	@Test
	func dailyHistoryIsBoundedWithoutLosingAllTimeTotals() throws {
		let fixture = try Fixture()
		var statistics = PlaytimeStatistics.empty

		for offset in 0..<50 {
			statistics.record(
				region: .global,
				startedAt: fixture.date(2026, 1, 1).addingTimeInterval(Double(offset) * 86_400),
				duration: 60,
				calendar: fixture.calendar
			)
		}

		#expect(statistics.days.count == AppConstants.Playtime.dailyHistoryLimit)
		#expect(statistics.totalDuration == 3_000)
	}

	@Test
	func restartDiscardsAnUnfinishedSessionWithoutInventingTime() throws {
		let fixture = try Fixture()
		let sessionID = UUID()
		let first = fixture.controller(now: { fixture.date(2026, 4, 1) }, uptime: { 500 })
		first.start(sessionID: sessionID, region: .japan)

		let restarted = fixture.controller(now: { fixture.date(2026, 4, 2) }, uptime: { 900 })
		#expect(restarted.statistics.activeSession == nil)
		#expect(restarted.totalDuration == 0)

		let reloaded = fixture.controller()
		#expect(reloaded.statistics.activeSession == nil)
	}

	@Test
	func resetDuringAGameCountsOnlyTimeAfterReset() throws {
		let fixture = try Fixture()
		var uptime: TimeInterval = 100
		var now = fixture.date(2026, 5, 1)
		let controller = fixture.controller(now: { now }, uptime: { uptime })
		let sessionID = UUID()
		controller.start(sessionID: sessionID, region: .korea)
		uptime = 130
		now = fixture.date(2026, 5, 1, hour: 1)

		controller.reset()
		uptime = 150

		#expect(controller.finish(sessionID: sessionID) == 20)
		#expect(controller.totalDuration == 20)
		#expect(controller.statistics.latestSession?.startedAt == now)
	}

	@Test
	func corruptedAndOversizedFilesStartWithAnEmptyState() throws {
		let corrupt = try Fixture()
		try Data("not json".utf8).write(to: corrupt.statisticsURL)
		#expect(corrupt.controller().statistics == .empty)

		let oversized = try Fixture()
		try Data(repeating: 0, count: AppConstants.Playtime.statisticsMaximumBytes + 1)
			.write(to: oversized.statisticsURL)
		#expect(oversized.controller().statistics == .empty)
	}

	@Test
	func symlinkedStatisticsStartWithAnEmptyState() throws {
		let fixture = try Fixture()
		let target = fixture.root.appending(path: "outside.json")
		let data = try JSONEncoder().encode(PlaytimeStatistics.empty)
		try data.write(to: target)
		try FileManager.default.createSymbolicLink(
			at: fixture.statisticsURL,
			withDestinationURL: target
		)

		#expect(fixture.controller().statistics == .empty)
	}
}

@MainActor
private struct Fixture {
	let root: URL
	let statisticsURL: URL
	let log: LauncherLog
	let calendar: Calendar

	init() throws {
		root = FileManager.default.temporaryDirectory.appending(
			path: "PlaytimeStatisticsTests.\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		statisticsURL = root.appending(path: "playtime.json")
		log = LauncherLog(fileURL: root.appending(path: "launcher.log"))
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
		self.calendar = calendar
	}

	func controller(
		now: @escaping () -> Date = { Date(timeIntervalSince1970: 0) },
		uptime: @escaping () -> TimeInterval = { 0 }
	) -> PlaytimeStatisticsController {
		PlaytimeStatisticsController(
			fileURL: statisticsURL,
			log: log,
			now: now,
			uptime: uptime,
			calendar: calendar
		)
	}

	func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
	}
}
