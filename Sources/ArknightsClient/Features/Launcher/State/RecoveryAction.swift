// SPDX-License-Identifier: MPL-2.0

import Foundation

enum RecoveryAction: String, CaseIterable, Identifiable, Sendable {
	case retry
	case openTroubleshooting
	case reportProblem
	case repair

	var id: String { rawValue }
}
