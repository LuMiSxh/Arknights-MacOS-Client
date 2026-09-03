// SPDX-License-Identifier: MPL-2.0

import Foundation

enum MaintenanceActivity: Equatable, Sendable {
	case clearingCache
	case deletingWinePrefix
	case uninstalling
	case updatingLauncher
	case migratingStorage
}
