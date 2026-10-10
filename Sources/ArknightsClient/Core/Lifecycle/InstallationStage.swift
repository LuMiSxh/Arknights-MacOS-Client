// SPDX-License-Identifier: MPL-2.0

import Foundation

enum InstallationStage: Equatable, Sendable {
	case preparing
	case verifying
	case downloading
	case pausing
}
