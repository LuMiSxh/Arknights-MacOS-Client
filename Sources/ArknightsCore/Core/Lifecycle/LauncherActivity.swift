// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Mutually exclusive work that can change game files or own the shared Wine runtime.
package enum LauncherActivity: Equatable, Sendable {
	case idle
	case maintaining(MaintenanceActivity)
	case installing(id: UUID, stage: InstallationStage)
	case preparingGame(sessionID: UUID)
	case launchingGame(sessionID: UUID, processIdentifier: Int32?)
	case runningGame(sessionID: UUID, processIdentifier: Int32)
	// The process identifier is nil when Stop interrupts Wine preparation before the game spawns.
	case stoppingGame(sessionID: UUID, processIdentifier: Int32?)

	package var activeGameSessionID: UUID? {
		switch self {
		case .preparingGame(let sessionID),
			.launchingGame(let sessionID, _),
			.runningGame(let sessionID, _),
			.stoppingGame(let sessionID, _):
			sessionID
		case .idle, .maintaining, .installing:
			nil
		}
	}

	package var gameProcessIdentifier: Int32? {
		switch self {
		case .launchingGame(_, let processIdentifier), .stoppingGame(_, let processIdentifier):
			processIdentifier
		case .runningGame(_, let processIdentifier): processIdentifier
		case .idle, .maintaining, .installing, .preparingGame: nil
		}
	}

	package var isGameActive: Bool { activeGameSessionID != nil }

	package var isGameProcessRunning: Bool {
		switch self {
		case .runningGame: true
		case .stoppingGame(_, let processIdentifier): processIdentifier != nil
		case .idle, .maintaining, .installing, .preparingGame, .launchingGame: false
		}
	}

	/// True from the moment the game process spawns, before its window is ready.
	package var hasGameProcess: Bool { gameProcessIdentifier != nil }

	package var isInstalling: Bool {
		if case .installing = self { return true }
		return false
	}
}

package enum InstallationStage: Equatable, Sendable {
	case preparing
	case verifying
	case downloading
	case pausing
}

package enum MaintenanceActivity: Equatable, Sendable {
	case clearingCache
	case deletingWinePrefix
	case uninstalling
	case updatingLauncher
	case migratingStorage
}
