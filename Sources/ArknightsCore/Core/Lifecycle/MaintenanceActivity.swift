// SPDX-License-Identifier: MPL-2.0

import Foundation

package enum MaintenanceActivity: Equatable, Sendable {
	case clearingCache
	case deletingWinePrefix
	case uninstalling
	case updatingLauncher
	case migratingStorage
}
