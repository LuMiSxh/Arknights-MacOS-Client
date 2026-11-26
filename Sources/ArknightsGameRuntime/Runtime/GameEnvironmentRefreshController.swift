// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import Foundation

/// The runtime operations a background refresh needs. `WineRuntime` is the production conformer.
protocol GameEnvironmentRefreshing: Sendable {
	/// Migrates one existing prefix when its runtime revision is stale. Returns whether it ran.
	func refreshPrefixIfPending(
		at prefixDirectory: URL,
		gameDirectory: URL,
		logURL: URL,
		log: LauncherLog?,
		spawnGate: WineProcessSpawnGate
	) async throws -> Bool
	func stopSynchronously(prefixDirectory: URL, log: LauncherLog?)
}

extension WineRuntime: GameEnvironmentRefreshing {}

/// Brings the Wine prefix of every installed server up to the current runtime revision while the
/// launcher is idle. Without it a prefix keeps private copies of the previous runtime's
/// libraries until the player next launches that server.
///
/// It runs the regular prefix migration, one prefix at a time, under a
/// `.updatingGameEnvironments` lease. A game launch cancels it; the prefix-wide shutdown still
/// completes before the lease ends. Migration state is saved after each step, so an interrupted
/// prefix resumes on the next refresh or launch. It never creates a prefix.
@MainActor
package final class GameEnvironmentRefreshController {
	typealias RuntimeProvider = @MainActor (RuntimeLane) throws -> any GameEnvironmentRefreshing

	private struct Target {
		let prefixDirectory: URL
		let gameDirectory: URL
		let logURL: URL
	}

	private static let activity = LauncherActivity.maintaining(.updatingGameEnvironments)

	private let lifecycle: LauncherLifecycleStore
	private let paths: AppPaths
	private let log: LauncherLog
	private let lane: @MainActor () -> RuntimeLane
	private let installedRegions: @MainActor () -> [GameRegion]
	private let gameDirectory: @MainActor (GameRegion) -> URL
	private let isLaunchPendingOrActive: @MainActor () -> Bool
	private let runtime: RuntimeProvider
	/// Owns the running pass; a pass that lost its token stops touching state.
	private let slot = TaskSlot()
	private var running: (lease: ActivityLease, task: Task<Void, Never>)?
	private var activePrefix: (runtime: any GameEnvironmentRefreshing, directory: URL)?
	private var isRequested = false
	private var isTerminating = false
	private var observedActivity: LauncherActivity

	package convenience init(
		lifecycle: LauncherLifecycleStore,
		paths: AppPaths,
		compatibilityManager: GameCompatibilityManager,
		lane: @escaping @MainActor () -> RuntimeLane,
		installedRegions: @escaping @MainActor () -> [GameRegion],
		gameDirectory: @escaping @MainActor (GameRegion) -> URL,
		isLaunchPendingOrActive: @escaping @MainActor () -> Bool,
		log: LauncherLog
	) {
		self.init(
			lifecycle: lifecycle,
			paths: paths,
			lane: lane,
			installedRegions: installedRegions,
			gameDirectory: gameDirectory,
			isLaunchPendingOrActive: isLaunchPendingOrActive,
			log: log,
			runtime: { lane in
				try GameSessionController.discoverRuntime(
					paths: paths, lane: lane, compatibilityManager: compatibilityManager)
			}
		)
	}

	init(
		lifecycle: LauncherLifecycleStore,
		paths: AppPaths,
		lane: @escaping @MainActor () -> RuntimeLane,
		installedRegions: @escaping @MainActor () -> [GameRegion],
		gameDirectory: @escaping @MainActor (GameRegion) -> URL,
		isLaunchPendingOrActive: @escaping @MainActor () -> Bool,
		log: LauncherLog,
		runtime: @escaping RuntimeProvider
	) {
		self.lifecycle = lifecycle
		self.paths = paths
		self.lane = lane
		self.installedRegions = installedRegions
		self.gameDirectory = gameDirectory
		self.isLaunchPendingOrActive = isLaunchPendingOrActive
		self.log = log
		self.runtime = runtime
		observedActivity = lifecycle.activity
		// The controller lives as long as the lifecycle store, so the observer is never removed.
		lifecycle.observeActivityChanges { [weak self] in
			self?.activityDidChange()
		}
	}

	/// Asks for a refresh. It starts at once when the launcher is idle; otherwise it starts when
	/// the launcher next becomes idle.
	package func requestRefresh() {
		isRequested = true
		startIfPossible()
	}

	/// Cancels a running refresh and returns after its prefix shutdown finished and the lease
	/// ended. The remaining prefixes are retried once the next activity ends.
	package func cancelAndWait() async {
		guard let task = running?.task else { return }
		isRequested = true
		task.cancel()
		await task.value
	}

	package func cancelForApplicationTermination() {
		isTerminating = true
		running?.task.cancel()
		if let activePrefix {
			activePrefix.runtime.stopSynchronously(
				prefixDirectory: activePrefix.directory, log: log)
		}
	}

	private func activityDidChange() {
		let previous = observedActivity
		observedActivity = lifecycle.activity
		// The pass that just ended may have yielded to a launch about to claim the lease.
		guard previous != Self.activity else { return }
		startIfPossible()
	}

	private func startIfPossible() {
		guard isRequested, !isTerminating, running == nil, !isLaunchPendingOrActive(),
			let lease = lifecycle.begin(Self.activity)
		else { return }
		isRequested = false
		let lane = lane()
		let task = slot.replace { [self] token in
			await perform(lane: lane, lease: lease, token: token)
		}
		running = (lease, task)
	}

	private func holds(_ lease: ActivityLease, _ token: TaskSlot.Token) -> Bool {
		slot.owns(token) && lifecycle.update(lease, to: Self.activity)
	}

	private func perform(lane: RuntimeLane, lease: ActivityLease, token: TaskSlot.Token) async {
		do {
			let runtime = try runtime(lane)
			passes: while true {
				for target in targets(for: lane) {
					guard !Task.isCancelled, holds(lease, token) else { break passes }
					let outcome = await refresh(target, using: runtime)
					guard holds(lease, token) else { break passes }
					switch outcome {
					case .refreshed:
						log.info(.runtime, "environment-updated", ["lane": lane.rawValue])
					case .upToDate: break
					case .cancelled: break passes
					case .failed(let diagnostic):
						// The next launch of that server repeats the migration and presents any error.
						log.error(
							.runtime, "environment-update-failed",
							["lane": lane.rawValue, "detail": diagnostic])
					}
				}
				guard isRequested, !Task.isCancelled else { break }
				isRequested = false
			}
		} catch {
			var path: URL?
			if case .missingRuntime(let url)? = error as? WineRuntimeDiscoveryError {
				path = url
			}
			let fields: LogFields = ["lane": lane.rawValue, "path": path]
			if WineRuntimeDiscoveryError.isNotInstalled(error) {
				log.warning(.runtime, "unavailable", fields, error: error)
			} else {
				// The next launch repeats the migration, so a skip is expected here.
				let skippedFields: LogFields = [
					"lane": lane.rawValue, "path": path, "error": logFields(for: error).id,
				]
				log.info(.runtime, "environment-update-skipped", skippedFields)
			}
		}
		// A stale lease cannot set idle, but the pass must still free the controller for the next one.
		if slot.owns(token) {
			running = nil
			slot.invalidate()
		}
		lifecycle.end(lease)
	}

	private enum Outcome {
		case refreshed, upToDate, cancelled
		case failed(String)
	}

	private func refresh(
		_ target: Target, using runtime: any GameEnvironmentRefreshing
	) async
		-> Outcome
	{
		activePrefix = (runtime, target.prefixDirectory)
		defer { activePrefix = nil }
		do {
			let ran = try await runtime.refreshPrefixIfPending(
				at: target.prefixDirectory,
				gameDirectory: target.gameDirectory,
				logURL: target.logURL,
				log: log,
				spawnGate: WineProcessSpawnGate()
			)
			return ran ? .refreshed : .upToDate
		} catch is CancellationError {
			return .cancelled
		} catch {
			return .failed(launcherDiagnosticDescription(for: error))
		}
	}

	/// One target per publisher whose prefix already exists and whose game is installed.
	private func targets(for lane: RuntimeLane) -> [Target] {
		var seen: Set<GamePublisher> = []
		var targets: [Target] = []
		for region in installedRegions() {
			let publisher = region.publisher
			guard seen.insert(publisher).inserted else { continue }
			let prefix = paths.winePrefix(for: publisher, lane: lane)
			let registry = prefix.appending(path: "system.reg")
			guard FileManager.default.fileExists(atPath: registry.path) else { continue }
			targets.append(
				Target(
					prefixDirectory: prefix,
					gameDirectory: gameDirectory(region),
					logURL: paths.publisherLogFile(for: publisher)
				))
		}
		return targets
	}
}
