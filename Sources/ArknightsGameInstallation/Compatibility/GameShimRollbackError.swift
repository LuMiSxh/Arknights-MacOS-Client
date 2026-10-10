// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

package struct GameShimRollbackError: LocalizedError, LauncherDiagnosticError, Sendable {
	let operationDescription: String
	let rollbackDescriptions: [String]

	package var errorDescription: String? {
		"Game-file compatibility setup could not be completed. Repair the game files and try again."
	}

	package var diagnosticDescription: String {
		let rollbackDescription = rollbackDescriptions.joined(separator: "; ")
		return
			"Compatibility update failed (\(operationDescription)); rollback also failed: \(rollbackDescription)"
	}
}
