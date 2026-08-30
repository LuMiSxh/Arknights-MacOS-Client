// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

enum GameProcessExitAction: Equatable {
	case ignore
	case startupFailure
	case gameExited
}

struct GameSessionTerminalFailure {
	let error: any Error
	let operation: SupportOperation
	let blocksGameLaunch: Bool
}

private struct PendingGameSessionTerminalFailure {
	let sessionID: UUID
	let failure: GameSessionTerminalFailure
}

/// Owns Wine discovery, launch, process monitoring, and prefix maintenance.
@MainActor
@Observable
final class GameSessionController {
	var runtimeName: String? {
		get { lifecycle.readiness.runtimeName }
		set { lifecycle.readiness.runtimeName = newValue }
	}
	var isGameActive: Bool { lifecycle.activity.isGameActive }
	var isGameProcessRunning: Bool { lifecycle.activity.isGameProcessRunning }
	var activeGameSessionID: UUID? { lifecycle.activity.activeGameSessionID }
	var canStopGame: Bool { Self.canStopGame(for: lifecycle.activity) }
	var canLaunch: Bool {
		installation.isInstalled && runtimeName != nil
			&& intelTranslation.allowsWine
			&& lifecycle.activity == .idle
	}

	let lifecycle: LauncherLifecycleStore
	let installation: InstallationController
	let settings: LauncherPreferencesController
	let intelTranslation: IntelTranslationController
	let paths: AppPaths
	let preferences: LauncherPreferencesStore
	let log: LauncherLog
	let gameCompatibilityManager: GameCompatibilityManager
	let playtimeStatistics: PlaytimeStatisticsController
	let graphicsDiagnosticsEnabled: Bool
	@ObservationIgnored var customGameIconURL: () -> URL? = { nil }
	@ObservationIgnored var runtimeSessionControllerProvider:
		@MainActor () throws -> any WineRuntimeSessionControlling
	@ObservationIgnored var launchTask: Task<Void, Never>?
	@ObservationIgnored var gameMonitorTask: Task<Void, Never>?
	@ObservationIgnored var gameProcessMonitorTask: Task<Void, Never>?
	@ObservationIgnored var activeGameModeEnabled = false
	@ObservationIgnored var activeGameRegion: GameRegion?
	@ObservationIgnored private var pendingTerminalFailure: PendingGameSessionTerminalFailure?
	var gameRunningSince: Date?

	init(
		lifecycle: LauncherLifecycleStore,
		installation: InstallationController,
		settings: LauncherPreferencesController,
		intelTranslation: IntelTranslationController,
		paths: AppPaths,
		preferences: LauncherPreferencesStore,
		log: LauncherLog,
		gameCompatibilityManager: GameCompatibilityManager,
		playtimeStatistics: PlaytimeStatisticsController,
		graphicsDiagnosticsEnabled: Bool
	) {
		self.lifecycle = lifecycle
		self.installation = installation
		self.settings = settings
		self.intelTranslation = intelTranslation
		self.paths = paths
		self.preferences = preferences
		self.log = log
		self.gameCompatibilityManager = gameCompatibilityManager
		runtimeSessionControllerProvider = {
			try WineRuntime.discover(compatibilityManager: gameCompatibilityManager)
		}
		self.playtimeStatistics = playtimeStatistics
		self.graphicsDiagnosticsEnabled = graphicsDiagnosticsEnabled
	}

	deinit {
		launchTask?.cancel()
		gameMonitorTask?.cancel()
		gameProcessMonitorTask?.cancel()
	}

	static func canStopGame(for activity: LauncherActivity) -> Bool {
		if case .runningGame = activity { return true }
		return false
	}

	static func directWineProcessExitAction(
		activity: LauncherActivity,
		sessionID: UUID
	) -> GameProcessExitAction {
		guard activity.activeGameSessionID == sessionID else { return .ignore }
		switch activity {
		case .preparingGame, .launchingGame: return .startupFailure
		case .runningGame: return .gameExited
		case .stoppingGame: return .ignore
		case .idle, .maintaining, .installing: return .ignore
		}
	}

	func rememberTerminalFailure(
		_ failure: GameSessionTerminalFailure?,
		for sessionID: UUID
	) {
		guard let failure else { return }
		pendingTerminalFailure = PendingGameSessionTerminalFailure(
			sessionID: sessionID,
			failure: failure
		)
	}

	func takeTerminalFailure(for sessionID: UUID) -> GameSessionTerminalFailure? {
		guard pendingTerminalFailure?.sessionID == sessionID else { return nil }
		defer { pendingTerminalFailure = nil }
		return pendingTerminalFailure?.failure
	}

	func resetTerminalFailure() {
		pendingTerminalFailure = nil
	}
}
