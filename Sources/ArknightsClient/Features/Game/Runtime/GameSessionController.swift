// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

enum GameProcessExitAction: Equatable {
	case ignore
	case startupFailure
	case gameExited
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
	let graphicsDiagnosticsEnabled: Bool
	@ObservationIgnored var customGameIconURL: () -> URL? = { nil }
	@ObservationIgnored var launchTask: Task<Void, Never>?
	@ObservationIgnored var gameMonitorTask: Task<Void, Never>?
	@ObservationIgnored var gameProcessMonitorTask: Task<Void, Never>?
	@ObservationIgnored var activeGameModeEnabled = false
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
		case .runningGame, .stoppingGame: return .gameExited
		case .idle, .maintaining, .installing: return .ignore
		}
	}
}
