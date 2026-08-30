// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

@MainActor
@Observable
final class PlaytimeStatisticsController {
	private(set) var statistics: PlaytimeStatistics

	@ObservationIgnored private let fileURL: URL
	@ObservationIgnored private let log: LauncherLog
	@ObservationIgnored private let now: () -> Date
	@ObservationIgnored private let uptime: () -> TimeInterval
	@ObservationIgnored private let calendar: Calendar
	@ObservationIgnored private var monotonicStart: TimeInterval?

	init(
		fileURL: URL,
		log: LauncherLog,
		now: @escaping () -> Date = { .now },
		uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
		calendar: Calendar = .autoupdatingCurrent
	) {
		self.fileURL = fileURL
		self.log = log
		self.now = now
		self.uptime = uptime
		self.calendar = calendar

		do {
			statistics = try Self.load(from: fileURL)
		} catch {
			statistics = .empty
			Self.logPersistenceError(error, operation: "load", log: log)
		}

		if statistics.activeSession != nil {
			statistics.activeSession = nil
			save()
			Task { [log] in
				await log.info("Discarded an unfinished playtime session after launcher restart")
			}
		}
	}

	var totalDuration: TimeInterval { statistics.totalDuration }

	func duration(for region: GameRegion) -> TimeInterval {
		statistics.duration(for: region)
	}

	func duration(inLast dayCount: Int) -> TimeInterval {
		statistics.duration(inLast: dayCount, now: now(), calendar: calendar)
	}

	func start(sessionID: UUID, region: GameRegion) {
		guard statistics.activeSession == nil else { return }
		let startedAt = now()
		statistics.activeSession = .init(id: sessionID, region: region, startedAt: startedAt)
		monotonicStart = uptime()
		save()
	}

	@discardableResult
	func finish(sessionID: UUID) -> TimeInterval? {
		guard
			let active = statistics.activeSession,
			active.id == sessionID,
			let monotonicStart
		else { return nil }
		let duration = max(0, uptime() - monotonicStart)
		statistics.activeSession = nil
		self.monotonicStart = nil
		statistics.record(
			region: active.region,
			startedAt: active.startedAt,
			duration: duration,
			calendar: calendar
		)
		save()
		return duration
	}

	func reset() {
		let active = statistics.activeSession
		statistics = .empty
		if let active {
			statistics.activeSession = .init(
				id: active.id,
				region: active.region,
				startedAt: now()
			)
			monotonicStart = uptime()
		}
		save()
	}

	private func save() {
		do {
			try FileManager.default.createDirectory(
				at: fileURL.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			let encoder = JSONEncoder()
			encoder.dateEncodingStrategy = .iso8601
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			var data = try encoder.encode(statistics)
			data.append(0x0A)
			try data.write(to: fileURL, options: .atomic)
		} catch {
			Self.logPersistenceError(error, operation: "save", log: log)
		}
	}

	private static func load(from fileURL: URL) throws -> PlaytimeStatistics {
		guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
		let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
		guard (values.fileSize ?? 0) <= AppConstants.Playtime.statisticsMaximumBytes else {
			throw PlaytimeStatisticsError.fileTooLarge
		}
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return try decoder.decode(PlaytimeStatistics.self, from: Data(contentsOf: fileURL))
			.validated()
	}

	private static func logPersistenceError(
		_ error: Error,
		operation: String,
		log: LauncherLog
	) {
		Task { [log] in
			await log.error(
				"Could not \(operation) local playtime statistics: \(error.localizedDescription)"
			)
		}
	}
}
