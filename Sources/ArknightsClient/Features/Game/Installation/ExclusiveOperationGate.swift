// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Lets a caller confirm it still owns a long-running operation before finishing it, so a
/// stale `Task` that lost a race (e.g. a cancelled install superseded by a new one) can't
/// clear state that already belongs to the operation that replaced it.
struct ExclusiveOperationGate: Sendable {
	private var activeToken: UUID?

	mutating func begin() -> UUID? {
		guard activeToken == nil else { return nil }
		let token = UUID()
		activeToken = token
		return token
	}

	func owns(_ token: UUID) -> Bool {
		activeToken == token
	}

	mutating func finish(_ token: UUID) {
		guard activeToken == token else { return }
		activeToken = nil
	}
}
