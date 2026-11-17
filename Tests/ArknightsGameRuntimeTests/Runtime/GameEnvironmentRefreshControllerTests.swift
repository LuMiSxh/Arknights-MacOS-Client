// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Synchronization
import Testing

@testable import ArknightsCore
@testable import ArknightsGameRuntime

private let yostar = "yostar"
private let hypergryph = "hypergryph"

/// Stands in for the runtime. Keys are the publisher directory names.
private final class RefresherSpy: GameEnvironmentRefreshing {
	private struct State {
		var calls: [String] = []
		var shutdowns: [String] = []
		var active = 0
		var maxActive = 0
	}

	private let state = Mutex(State())
	private let stale: Set<String>
	/// A gated prefix waits for its gate, or for cancellation, which then runs its shutdown.
	private let gates: [String: Signal]
	let entered: [String: Signal]

	init(stale: Set<String>, gated: Set<String> = []) {
		self.stale = stale
		gates = Dictionary(uniqueKeysWithValues: gated.map { ($0, Signal()) })
		entered = Dictionary(uniqueKeysWithValues: stale.map { ($0, Signal()) })
	}

	var calls: [String] { state.withLock { $0.calls } }
	var shutdowns: [String] { state.withLock { $0.shutdowns } }
	var maxActive: Int { state.withLock { $0.maxActive } }

	func release(_ name: String) { gates[name]?.fire() }

	func refreshPrefixIfPending(
		at prefixDirectory: URL,
		gameDirectory: URL,
		logURL: URL,
		log: LauncherLog?,
		spawnGate: WineProcessSpawnGate
	) async throws -> Bool {
		// Environment folders are named `<publisher>-<lane>`.
		let name =
			prefixDirectory.lastPathComponent.split(separator: "-").first.map(String.init) ?? ""
		state.withLock {
			$0.calls.append(name)
			$0.active += 1
			$0.maxActive = max($0.maxActive, $0.active)
		}
		defer { state.withLock { $0.active -= 1 } }
		guard stale.contains(name) else { return false }
		entered[name]?.fire()
		if let gate = gates[name] {
			await gate.wait()
			if Task.isCancelled {
				// The shutdown suspends, as the real `wineserver -w` does.
				await Task.yield()
				state.withLock { $0.shutdowns.append(name) }
				throw CancellationError()
			}
		}
		state.withLock { $0.shutdowns.append(name) }
		return true
	}

	func stopSynchronously(prefixDirectory: URL, log: LauncherLog?) {}
}

@MainActor
private final class LaunchFlag {
	var isPending = false
}

@MainActor
private struct RefreshFixture {
	let storage: TemporaryDirectory
	let paths: AppPaths
	let lifecycle: LauncherLifecycleStore
	let controller: GameEnvironmentRefreshController
	let launch = LaunchFlag()

	init(
		spy: RefresherSpy,
		installed: [GameRegion],
		existingPrefixes: [GamePublisher]
	) throws {
		storage = try TemporaryDirectory("GameEnvironmentRefreshTests")
		let root = storage.url
		paths = AppPaths(
			applicationSupportDirectory: root, cachesDirectory: root,
			libraryDirectory: root, downloadsDirectory: root)
		for publisher in existingPrefixes {
			try Self.createPrefix(paths.winePrefix(for: publisher, lane: .x86))
		}
		lifecycle = makeLifecycleStore(in: storage)
		let gameRoot = root.appending(path: "Games", directoryHint: .isDirectory)
		let flag = launch
		controller = GameEnvironmentRefreshController(
			lifecycle: lifecycle,
			paths: paths,
			lane: { .x86 },
			installedRegions: { installed },
			gameDirectory: {
				gameRoot.appending(path: $0.serverIdentifier, directoryHint: .isDirectory)
			},
			isLaunchPendingOrActive: { flag.isPending },
			log: LauncherLog(fileURL: root.appending(path: "refresh.log")),
			runtime: { _ in spy }
		)
	}

	static func createPrefix(_ prefix: URL) throws {
		try FileManager.default.createDirectory(at: prefix, withIntermediateDirectories: true)
		try Data().write(to: prefix.appending(path: "system.reg"))
	}
}

@MainActor
struct GameEnvironmentRefreshControllerTests {
	@Test(.timeLimit(.minutes(1)))
	func refreshesOnlyExistingPrefixesOfInstalledServersOneAtATime() async throws {
		let spy = RefresherSpy(stale: [yostar, hypergryph])
		let fixture = try RefreshFixture(
			spy: spy,
			// Global and Japan share one prefix; Taiwan has none and must stay uncreated.
			installed: [.global, .japan, .taiwan, .china],
			existingPrefixes: [.yostar, .hypergryph])
		defer { fixture.storage.remove() }
		// A prefix of the other lane is not part of this refresh.
		try RefreshFixture.createPrefix(fixture.paths.winePrefix(for: .gryphline, lane: .arm))

		fixture.controller.requestRefresh()
		await waitForCondition { fixture.lifecycle.activity == .idle }

		#expect(spy.calls == [yostar, hypergryph])
		#expect(spy.maxActive == 1)
		let missing = fixture.paths.winePrefix(for: .gryphline, lane: .x86)
		#expect(!FileManager.default.fileExists(atPath: missing.path))
	}

	@Test(.timeLimit(.minutes(1)))
	func cancellationReleasesTheLauncherOnlyAfterTheShutdownAndResumesAfterTheLaunch() async throws
	{
		let spy = RefresherSpy(stale: [yostar, hypergryph], gated: [yostar])
		let fixture = try RefreshFixture(
			spy: spy, installed: [.global, .china], existingPrefixes: [.yostar, .hypergryph])
		defer { fixture.storage.remove() }

		fixture.controller.requestRefresh()
		#expect(fixture.lifecycle.activity == .maintaining(.updatingGameEnvironments))
		await spy.entered[yostar]?.wait()
		await fixture.controller.cancelAndWait()

		#expect(spy.shutdowns == [yostar])
		#expect(fixture.lifecycle.activity == .idle)
		// The launch that caused the cancel claims the launcher; maintenance does not restart.
		#expect(spy.calls == [yostar])
		let launch = try #require(fixture.lifecycle.begin(.preparingGame(sessionID: UUID())))
		fixture.lifecycle.end(launch)
		spy.release(yostar)
		await waitForCondition { fixture.lifecycle.activity == .idle && spy.calls.count == 3 }

		#expect(spy.calls == [yostar, yostar, hypergryph])
	}

	@Test(.timeLimit(.minutes(1)))
	func waitsForTheLauncherToBeIdleAndForAPendingLaunch() async throws {
		let spy = RefresherSpy(stale: [yostar])
		let fixture = try RefreshFixture(
			spy: spy, installed: [.global], existingPrefixes: [.yostar])
		defer { fixture.storage.remove() }
		let install = try #require(
			fixture.lifecycle.begin(.installing(id: UUID(), stage: .downloading)))

		fixture.controller.requestRefresh()
		#expect(spy.calls.isEmpty)
		fixture.launch.isPending = true
		fixture.lifecycle.end(install)
		#expect(spy.calls.isEmpty)
		#expect(fixture.lifecycle.activity == .idle)

		fixture.launch.isPending = false
		let next = try #require(fixture.lifecycle.begin(.maintaining(.clearingCache)))
		fixture.lifecycle.end(next)
		await waitForCondition { fixture.lifecycle.activity == .idle && spy.calls.count == 1 }

		#expect(spy.calls == [yostar])
	}

	@Test(.timeLimit(.minutes(1)))
	func aStaleLeaseNeverSetsIdle() async throws {
		let spy = RefresherSpy(stale: [yostar], gated: [yostar])
		let fixture = try RefreshFixture(
			spy: spy, installed: [.global], existingPrefixes: [.yostar])
		defer { fixture.storage.remove() }

		fixture.controller.requestRefresh()
		await spy.entered[yostar]?.wait()
		// Another owner takes over the activity and invalidates the maintenance lease.
		let sessionID = UUID()
		fixture.lifecycle.simulateActivity(.preparingGame(sessionID: sessionID))
		spy.release(yostar)
		await fixture.controller.cancelAndWait()

		#expect(fixture.lifecycle.activity == .preparingGame(sessionID: sessionID))
	}
}
