// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Serializes Wine process creation with a stop request for the same game session.
final class WineProcessSpawnGate: @unchecked Sendable {
	private let lock = NSLock()
	private let beforeSpawnAttempt: @Sendable () -> Void
	private var allowsSpawn = true

	init(beforeSpawnAttempt: @escaping @Sendable () -> Void = {}) {
		self.beforeSpawnAttempt = beforeSpawnAttempt
	}

	func denyFurtherSpawns() {
		lock.lock()
		allowsSpawn = false
		lock.unlock()
	}

	func runIfAllowed<T>(_ operation: () throws -> T) throws -> T {
		beforeSpawnAttempt()
		lock.lock()
		defer { lock.unlock() }
		guard allowsSpawn else { throw CancellationError() }
		return try operation()
	}
}
