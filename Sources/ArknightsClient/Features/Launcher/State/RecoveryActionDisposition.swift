// SPDX-License-Identifier: MPL-2.0

import Foundation

enum RecoveryActionDisposition: Sendable {
	case completed
	case repairConfirmationRequired
	case ignored
}
