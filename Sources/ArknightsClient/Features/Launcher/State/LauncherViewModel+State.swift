// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	var versionText: String {
		installedVersion ?? configuration?.gameLatestVersion ?? "—"
	}

	var installSizeText: String {
		configuration?.decompressionSize ?? "—"
	}

	var phase: LauncherPhase {
		switch state.activity {
		case .installing:
			.downloading
		case .preparingGame:
			.migrating
		case .launchingGame:
			.launching
		case .runningGame(_, let processIdentifier),
			.stoppingGame(_, let processIdentifier):
			.running(processIdentifier: processIdentifier)
		case .idle, .maintaining:
			state.refresh.isChecking ? .checking : .ready
		}
	}

	var isDownloading: Bool { state.activity.isInstalling }

	var canInstall: Bool {
		configuration != nil && state.activity == .idle
	}

	var canModifyGameFiles: Bool { state.activity == .idle }

	/// Launch options are captured before Wine starts and must stay stable until the active
	/// game session has fully stopped, including its native Game Mode cleanup.
	var canModifyLaunchOptions: Bool { !isGameActive }

	var canLaunch: Bool {
		isInstalled && runtimeName != nil && intelTranslationState.allowsWine
			&& state.activity == .idle
	}

	var isGameRunning: Bool { isGameActive }

	var canStopGame: Bool { Self.canStopGame(for: state.activity) }

	static func canStopGame(for activity: LauncherActivity) -> Bool {
		if case .runningGame = activity { return true }
		return false
	}

	static func directWineProcessExitAction(
		activity: LauncherActivity,
		sessionID: UUID
	) -> DirectWineProcessExitAction {
		switch activity {
		case .launchingGame(let activeSessionID, _) where activeSessionID == sessionID:
			.startupFailure
		case .runningGame(let activeSessionID, _) where activeSessionID == sessionID,
			.stoppingGame(let activeSessionID, _) where activeSessionID == sessionID:
			.gameExited
		default:
			.ignore
		}
	}

	var isGameActive: Bool { state.activity.isGameActive }

	var activeGameSessionID: UUID? { state.activity.activeGameSessionID }

	var isDeveloperMode: Bool {
		#if DEBUG
			developerScenario != nil
		#else
			false
		#endif
	}

	var isOnboardingPreview: Bool {
		#if DEBUG
			developerScenario == .onboarding || developerScenario == .onboardingRosetta
		#else
			false
		#endif
	}

	func setStatus(_ status: LauncherStatus, clearsFailure: Bool = true) {
		state.presentation.status = status
		if clearsFailure { state.presentation.failureMessage = nil }
	}

	func clearFailure() {
		state.presentation.failureMessage = nil
	}
}
