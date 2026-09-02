// SPDX-License-Identifier: MPL-2.0

import Foundation

enum SupportOperation: String, Codable, Sendable {
	case launcher
	case configurationRefresh = "configuration-refresh"
	case install
	case update
	case repair
	case uninstall
	case cacheClearing = "cache-clearing"
	case rosettaInstallation = "rosetta-installation"
	case runtimeDiscovery = "runtime-discovery"
	case prefixMigration = "prefix-migration"
	case prefixDeletion = "prefix-deletion"
	case launch
	case runtimeStop = "runtime-stop"
	case runtimeExit = "runtime-exit"
}
