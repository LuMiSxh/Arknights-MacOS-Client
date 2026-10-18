// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

@MainActor
struct PlaytimeStatisticsPersistenceTests {
	private static let calendar = Calendar(identifier: .gregorian)

	private typealias Fixture = (
		dir: TemporaryDirectory, store: PlaytimeStatisticsStore,
		controller: PlaytimeStatisticsController
	)

	private func makeFixture(persisted seconds: TimeInterval) throws -> Fixture {
		let dir = try TemporaryDirectory("PlaytimeStatisticsPersistenceTests")
		let url = dir.url.appending(path: "playtime.json")
		let log = LauncherLog(fileURL: dir.url.appending(path: "launcher.log"))
		let store = PlaytimeStatisticsStore(fileURL: url, log: log)
		var persisted = PlaytimeStatistics.empty
		persisted.record(
			region: .global, startedAt: Date(timeIntervalSince1970: 0), duration: seconds,
			calendar: Self.calendar)
		store.saveSynchronously(persisted)
		var tick: TimeInterval = 0
		let controller = PlaytimeStatisticsController(
			fileURL: url, log: log, now: { Date(timeIntervalSince1970: 86_400) },
			uptime: {
				tick += 10
				return tick
			}, calendar: Self.calendar)
		return (dir, PlaytimeStatisticsStore(fileURL: url, log: log), controller)
	}

	@Test
	func recordBeforeLoadMergesOverPersistedData() async throws {
		let (dir, _, controller) = try makeFixture(persisted: 100)
		defer { dir.remove() }
		let id = UUID()
		controller.start(sessionID: id, region: .global)
		controller.finish(sessionID: id)
		await controller.loaded()
		#expect(controller.totalDuration == 110)
	}

	@Test
	func resetBeforeLoadDiscardsPersistedData() async throws {
		let (dir, _, controller) = try makeFixture(persisted: 100)
		defer { dir.remove() }
		controller.reset()
		await controller.loaded()
		#expect(controller.totalDuration == 0)
	}

	@Test(arguments: [false, true])
	func terminationPersistsSessionEvenBeforeLoadFinishes(reset: Bool) async throws {
		let (dir, store, controller) = try makeFixture(persisted: 100)
		defer { dir.remove() }
		if reset { controller.reset() }
		let id = UUID()
		controller.start(sessionID: id, region: .global)
		controller.finish(sessionID: id)
		controller.persistForTermination()
		await controller.loaded()
		#expect(store.loadSynchronously().totalDuration == (reset ? 10 : 110))
	}

	@Test
	func terminationWriteIsNeverOvertakenByAnEarlierSave() async throws {
		let (dir, store, controller) = try makeFixture(persisted: 0)
		defer { dir.remove() }
		await controller.loaded()
		for _ in 0..<50 {
			let id = UUID()
			controller.start(sessionID: id, region: .global)
			controller.finish(sessionID: id)
		}
		controller.persistForTermination()
		for _ in 0..<5 { await Task.yield() }
		#expect(store.loadSynchronously().totalDuration == controller.totalDuration)
		#expect(controller.totalDuration == 500)
	}
}
