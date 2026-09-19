// SPDX-License-Identifier: MPL-2.0

import Foundation

struct GameShimRollbackError: LocalizedError, LauncherDiagnosticError, Sendable {
	let operationDescription: String
	let rollbackDescriptions: [String]

	var errorDescription: String? {
		"Game-file compatibility setup could not be completed. Repair the game files and try again."
	}

	var diagnosticDescription: String {
		let rollbackDescription = rollbackDescriptions.joined(separator: "; ")
		return
			"Compatibility update failed (\(operationDescription)); rollback also failed: \(rollbackDescription)"
	}
}
