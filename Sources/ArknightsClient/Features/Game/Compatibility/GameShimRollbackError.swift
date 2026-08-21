// SPDX-License-Identifier: MPL-2.0

import Foundation

struct GameShimRollbackError: LocalizedError, Sendable {
	let operationDescription: String
	let rollbackDescriptions: [String]

	var errorDescription: String? {
		let rollbackDescription = rollbackDescriptions.joined(separator: "; ")
		return
			"Compatibility update failed (\(operationDescription)); rollback also failed: \(rollbackDescription)"
	}
}
