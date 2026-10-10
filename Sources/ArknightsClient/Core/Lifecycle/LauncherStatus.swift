// SPDX-License-Identifier: MPL-2.0

import Foundation

enum LauncherStatus: Equatable, Sendable {
	case checking
	case ready
	case updateAvailable
	case install
	case preparingInstallation
	case verifyingInstallation
	case downloading
	case pausing
	case paused
	case updated
	case preparingWine
	case startingGame
	case running
	case stoppingGame
	case movingToTrash
	case uninstalled
	case migratingStorage
	case deletingWinePrefix
	case winePrefixDeleted
	case winePrefixResetScheduled
	case gameExecutableNotFound

	/// Work without measurable progress, shown with the pulsing HUD outline instead of a fraction.
	var isIndeterminateWork: Bool {
		switch self {
		case .preparingInstallation, .preparingWine, .startingGame, .stoppingGame,
			.movingToTrash, .migratingStorage, .deletingWinePrefix:
			true
		default:
			false
		}
	}

	var message: String {
		switch self {
		case .checking: "Checking…"
		case .ready: "Ready"
		case .updateAvailable: "Update available"
		case .install: "Install"
		case .preparingInstallation: "Preparing…"
		case .verifyingInstallation: "Verifying…"
		case .downloading: "Downloading…"
		case .pausing: "Pausing…"
		case .paused: "Paused"
		case .updated: "Updated"
		case .preparingWine: "Preparing Wine setup…"
		case .startingGame: "Starting…"
		case .running: "Running"
		case .stoppingGame: "Stopping…"
		case .movingToTrash: "Moving to Trash…"
		case .uninstalled: "Uninstalled"
		case .migratingStorage: "Updating launcher data…"
		case .deletingWinePrefix: "Deleting Wine prefix…"
		case .winePrefixDeleted: "Wine prefix deleted; setup will run again on next launch"
		case .winePrefixResetScheduled: "Wine setup will run again on next launch"
		case .gameExecutableNotFound: "Arknights.exe not found"
		}
	}
}
