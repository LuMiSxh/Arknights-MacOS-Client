// SPDX-License-Identifier: MPL-2.0

import Foundation

struct ExclusiveOperationGate: Sendable {
	private var activeToken: UUID?

	var isActive: Bool { activeToken != nil }

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
