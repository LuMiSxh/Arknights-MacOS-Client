// SPDX-License-Identifier: MPL-2.0

import Foundation

package enum RecoveryAction: String, CaseIterable, Identifiable, Sendable {
	case retry
	case installRosetta
	case openTroubleshooting
	case reportProblem
	case repair
	case deleteDataFolder
	case tryAgain
	case quit

	package var id: String { rawValue }
}

package enum RecoveryActionDisposition: Sendable {
	case completed
	case repairConfirmationRequired
	case deleteDataFolderConfirmationRequired
	case rosettaConfirmationRequired
	case ignored
}
