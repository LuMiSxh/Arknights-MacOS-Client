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
	case custom(String)

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
		case .custom(let message): message
		}
	}
}
