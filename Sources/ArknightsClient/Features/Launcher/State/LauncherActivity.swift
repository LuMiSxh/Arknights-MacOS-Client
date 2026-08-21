// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Mutually exclusive work that can change game files or own the shared Wine runtime.
enum LauncherActivity: Equatable, Sendable {
	case idle
	case maintaining(MaintenanceActivity)
	case installing(id: UUID, stage: InstallationStage)
	case preparingGame(sessionID: UUID)
	case launchingGame(sessionID: UUID, processIdentifier: Int32?)
	case runningGame(sessionID: UUID, processIdentifier: Int32)
	case stoppingGame(sessionID: UUID, processIdentifier: Int32)

	var activeGameSessionID: UUID? {
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

	var gameProcessIdentifier: Int32? {
		switch self {
		case .launchingGame(_, let processIdentifier): processIdentifier
		case .runningGame(_, let processIdentifier), .stoppingGame(_, let processIdentifier):
			processIdentifier
		case .idle, .maintaining, .installing, .preparingGame: nil
		}
	}

	var isGameActive: Bool { activeGameSessionID != nil }

	var isGameProcessRunning: Bool {
		switch self {
		case .runningGame, .stoppingGame: true
		case .idle, .maintaining, .installing, .preparingGame, .launchingGame: false
		}
	}

	var isInstalling: Bool {
		if case .installing = self { return true }
		return false
	}
}
