// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

// Finishing a session cancels its tasks and replaces this value with `nil`, so no field can
// outlive its session.
struct ActiveGameSession {
	let id: UUID
	// Ends only after prefix-wide shutdown completes.
	let lease: ActivityLease
	package let region: GameRegion
	let spawnGate: WineProcessSpawnGate

	var usesGameMode: Bool
	var isRuntimeStopInFlight = false
	var pendingTerminalFailure: GameSessionTerminalFailure?
	var launchTask: Task<Void, Never>?
	var monitorTask: Task<Void, Never>?
	var processMonitorTask: Task<Void, Never>?

	init(
		id: UUID,
		lease: ActivityLease,
		region: GameRegion,
		spawnGate: WineProcessSpawnGate,
		usesGameMode: Bool
	) {
		self.id = id
		self.lease = lease
		self.region = region
		self.spawnGate = spawnGate
		self.usesGameMode = usesGameMode
	}

	func cancelTasks() {
		launchTask?.cancel()
		monitorTask?.cancel()
		processMonitorTask?.cancel()
	}
}
