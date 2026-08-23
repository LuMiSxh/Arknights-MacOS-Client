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
		case .checking: L10n.string(.Launcher.launcherStatusChecking)
		case .ready: L10n.string(.Launcher.launcherStatusReady)
		case .updateAvailable: L10n.string(.Launcher.launcherStatusUpdateAvailable)
		case .install: L10n.string(.Launcher.launcherStatusInstall)
		case .preparingInstallation: L10n.string(.Launcher.launcherStatusPreparing)
		case .verifyingInstallation: L10n.string(.Launcher.launcherStatusVerifying)
		case .downloading: L10n.string(.Launcher.launcherStatusDownloading)
		case .pausing: L10n.string(.Launcher.launcherStatusPausing)
		case .paused: L10n.string(.Launcher.launcherStatusPaused)
		case .updated: L10n.string(.Launcher.launcherStatusUpdated)
		case .preparingWine: L10n.string(.Launcher.launcherStatusPreparingWine)
		case .startingGame: L10n.string(.Launcher.launcherStatusStarting)
		case .running: L10n.string(.Launcher.launcherStatusRunning)
		case .stoppingGame: L10n.string(.Launcher.launcherStatusStopping)
		case .movingToTrash: L10n.string(.Launcher.launcherStatusMovingToTrash)
		case .uninstalled: L10n.string(.Launcher.launcherStatusUninstalled)
		case .custom(let message): message
		}
	}
}
