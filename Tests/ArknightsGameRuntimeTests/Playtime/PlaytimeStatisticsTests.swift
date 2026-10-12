// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsGameRuntime

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
	func corruptedAndOversizedFilesStartWithAnEmptyState() throws {
		let corrupt = try Fixture()
		try Data("not json".utf8).write(to: corrupt.statisticsURL)
		#expect(corrupt.controller().statistics == .empty)
		#expect(!FileManager.default.fileExists(atPath: corrupt.statisticsURL.path))
		#expect(
			try Data(contentsOf: corrupt.statisticsURL.appendingPathExtension("unreadable"))
				== Data("not json".utf8))

		let oversized = try Fixture()
		try Data(repeating: 0, count: AppConstants.Playtime.statisticsMaximumBytes + 1)
			.write(to: oversized.statisticsURL)
		#expect(oversized.controller().statistics == .empty)

		let linked = try Fixture()
		let target = linked.root.appending(path: "outside.json")
		try JSONEncoder().encode(PlaytimeStatistics.empty).write(to: target)
		try FileManager.default.createSymbolicLink(
			at: linked.statisticsURL, withDestinationURL: target)
		#expect(linked.controller().statistics == .empty)
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
