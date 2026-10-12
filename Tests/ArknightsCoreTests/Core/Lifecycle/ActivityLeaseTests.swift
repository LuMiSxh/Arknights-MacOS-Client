// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

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
		#expect(!lifecycle.end(lease))
		#expect(lifecycle.begin(first) != nil)

		let pending = makeLifecycleStore()
		pending.beginLauncherUpdate()
		#expect(pending.begin(first) == nil)
		pending.finishLauncherUpdate()
		#expect(pending.begin(first) != nil)
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
}

@MainActor
private func makeLifecycleStore() -> LauncherLifecycleStore {
	let fileURL = FileManager.default.temporaryDirectory.appending(
		path: "ActivityLeaseTests.\(UUID().uuidString).log"
	)
	return LauncherLifecycleStore(log: LauncherLog(fileURL: fileURL))
}
