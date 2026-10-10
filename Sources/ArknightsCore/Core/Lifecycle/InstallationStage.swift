// SPDX-License-Identifier: MPL-2.0

import Foundation

package enum InstallationStage: Equatable, Sendable {
	case preparing
	case verifying
	case downloading
	case pausing
}
