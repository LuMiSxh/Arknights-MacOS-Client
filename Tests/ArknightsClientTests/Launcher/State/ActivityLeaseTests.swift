// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct ActivityLeaseTests {
	private let first = LauncherActivity.maintaining(.uninstalling)
	private let second = LauncherActivity.maintaining(.clearingCache)

	@Test
	func beginClaimsTheActivityOnlyWhenIdle() throws {
		let lifecycle = makeLifecycleStore()

		let lease = try #require(lifecycle.begin(first))

		#expect(lifecycle.activity == first)
		#expect(lifecycle.begin(second) == nil)
		#expect(lifecycle.activity == first)
		#expect(lifecycle.end(lease))
	}

	@Test
	func beginFailsWhileLauncherUpdateIsPending() {
		let lifecycle = makeLifecycleStore()
		lifecycle.beginLauncherUpdate()

		#expect(lifecycle.begin(first) == nil)

		lifecycle.finishLauncherUpdate()
		#expect(lifecycle.begin(first) != nil)
	}

	@Test
	func staleLeaseCannotSetIdleOrUpdate() throws {
		let lifecycle = makeLifecycleStore()
		let stale = try #require(lifecycle.begin(first))
		#expect(lifecycle.end(stale))
		let current = try #require(lifecycle.begin(second))

		#expect(!lifecycle.end(stale))
		#expect(!lifecycle.update(stale, to: first))
		#expect(lifecycle.activity == second)
		#expect(lifecycle.end(current))
		#expect(lifecycle.activity == .idle)
	}

	@Test
	func simulatedActivityInvalidatesTheLease() throws {
		let lifecycle = makeLifecycleStore()
		let lease = try #require(lifecycle.begin(first))
		let simulated = LauncherActivity.preparingGame(sessionID: UUID())

		lifecycle.simulateActivity(simulated)

		#expect(!lifecycle.end(lease))
		#expect(!lifecycle.update(lease, to: first))
		#expect(lifecycle.activity == simulated)
	}

	@Test
	func endingClearsTheLeaseSoNewWorkCanBegin() throws {
		let lifecycle = makeLifecycleStore()
		let lease = try #require(lifecycle.begin(first))

		#expect(lifecycle.end(lease))
		#expect(!lifecycle.end(lease))
		#expect(lifecycle.begin(first) != nil)
	}

	@Test
	func observersFireOncePerRealChange() throws {
		let lifecycle = makeLifecycleStore()
		var count = 0
		lifecycle.observeActivityChanges { count += 1 }

		let lease = try #require(lifecycle.begin(first))
		#expect(count == 1)
		#expect(lifecycle.update(lease, to: first))
		#expect(count == 1)
		#expect(lifecycle.update(lease, to: second))
		#expect(count == 2)
		#expect(lifecycle.end(lease))
		#expect(count == 3)
		#expect(!lifecycle.end(lease))
		#expect(count == 3)
	}
}

@MainActor
private func makeLifecycleStore() -> LauncherLifecycleStore {
	let fileURL = FileManager.default.temporaryDirectory.appending(
		path: "ActivityLeaseTests.\(UUID().uuidString).log"
	)
	return LauncherLifecycleStore(log: LauncherLog(fileURL: fileURL))
}
