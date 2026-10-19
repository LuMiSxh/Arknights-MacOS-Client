// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation
import Observation

@MainActor
@Observable
package final class PlaytimeStatisticsController {
	private(set) var statistics: PlaytimeStatistics

	@ObservationIgnored private let log: LauncherLog
	@ObservationIgnored private let now: () -> Date
	@ObservationIgnored private let uptime: () -> TimeInterval
	@ObservationIgnored private let calendar: Calendar
	@ObservationIgnored private var monotonicStart: TimeInterval?
	@ObservationIgnored private let snapshotContinuation:
		AsyncStream<PlaytimeStatistics>.Continuation
	@ObservationIgnored private let store: PlaytimeStatisticsStore
	@ObservationIgnored private var loadTask: Task<Void, Never>?
	@ObservationIgnored private var isLoaded = false
	// Changes made before the load finishes; `applyLoaded` replays them over the persisted data.
	@ObservationIgnored private var discardsLoaded = false
	@ObservationIgnored private var unloadedRecords: [(GameRegion, Date, TimeInterval)] = []

	package init(
		fileURL: URL,
		log: LauncherLog,
		now: @escaping () -> Date = { .now },
		uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
		calendar: Calendar = .autoupdatingCurrent
	) {
		self.log = log
		self.now = now
		self.uptime = uptime
		self.calendar = calendar

		statistics = .empty
		let store = PlaytimeStatisticsStore(fileURL: fileURL, log: log)
		self.store = store
		// Only the latest snapshot matters, so a slow disk coalesces writes. One consumer writes
		// them in order, after the initial load, so an older snapshot never overwrites a newer one.
		let (snapshots, continuation) = AsyncStream<PlaytimeStatistics>.makeStream(
			bufferingPolicy: .bufferingNewest(1)
		)
		snapshotContinuation = continuation
		let loading = Task { [weak self] in
			let loaded = await store.load()
			self?.applyLoaded(loaded)
		}
		loadTask = loading
		Task {
			await loading.value
			for await snapshot in snapshots {
				await store.save(snapshot)
			}
		}
	}

	deinit {
		snapshotContinuation.finish()
	}

	/// Returns once the persisted statistics are merged into memory.
	func loaded() async {
		await loadTask?.value
	}

	/// Writes the final state before the process exits, which cannot wait for the asynchronous
	/// consumer. Loads first if the initial load is unfinished. Later asynchronous saves are dropped.
	func persistForTermination() {
		if !isLoaded { applyLoaded(store.loadSynchronously()) }
		store.saveSynchronously(statistics)
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
		if !isLoaded { unloadedRecords.append((active.region, active.startedAt, duration)) }
		save()
		return duration
	}

	func reset() {
		let active = statistics.activeSession
		statistics = .empty
		if !isLoaded {
			discardsLoaded = true
			unloadedRecords = []
		}
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

	private func applyLoaded(_ loaded: PlaytimeStatistics) {
		guard !isLoaded else { return }
		isLoaded = true
		var changedLocally = discardsLoaded || !unloadedRecords.isEmpty
		if !discardsLoaded {
			var merged = loaded
			merged.activeSession = nil
			for (region, startedAt, duration) in unloadedRecords {
				merged.record(
					region: region, startedAt: startedAt, duration: duration, calendar: calendar)
			}
			merged.activeSession = statistics.activeSession
			statistics = merged
		}
		unloadedRecords = []
		if statistics.activeSession != nil { changedLocally = true }
		if loaded.activeSession != nil {
			changedLocally = true
			log.info("Discarded an unfinished playtime session after launcher restart")
		}
		if changedLocally { save() }
	}

	/// Snapshots wait for the load, which saves the merged result itself.
	private func save() {
		guard isLoaded else { return }
		snapshotContinuation.yield(statistics)
	}
}
