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
		!applicationTerminationRequested
			&& installation.isInstalled && runtimeName != nil
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
	@ObservationIgnored var session: ActiveGameSession?
	@ObservationIgnored var applicationTerminationRequested = false
	/// Launch that passed the click guard but has no session yet. Blocks a second launch.
	@ObservationIgnored var pendingLaunchID: UUID?
	var gameRunningSince: Date?
	var sessionLease: ActivityLease? { session?.lease }
	var activeGameRegion: GameRegion? { session?.region }

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
		session?.cancelTasks()
	}

	static func canStopGame(for activity: LauncherActivity) -> Bool {
		switch activity {
		case .preparingGame, .launchingGame, .runningGame: true
		case .idle, .maintaining, .installing, .stoppingGame: false
		}
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
		guard let failure, session?.id == sessionID else { return }
		session?.pendingTerminalFailure = failure
	}

	func takeTerminalFailure(for sessionID: UUID) -> GameSessionTerminalFailure? {
		guard session?.id == sessionID else { return nil }
		defer { session?.pendingTerminalFailure = nil }
		return session?.pendingTerminalFailure
	}
}
