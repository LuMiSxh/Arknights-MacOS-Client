// SPDX-License-Identifier: MPL-2.0

import Foundation

package enum RecoveryAction: String, CaseIterable, Identifiable, Sendable {
	case retry
	case installRosetta
	case openTroubleshooting
	case reportProblem
	case repair

	package var id: String { rawValue }
}
