// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

/// Owns launcher state that spans otherwise independent features. Feature controllers use this
/// store for mutually exclusive activity and user-facing presentation, but never depend on the
/// root composition model.
@MainActor
@Observable
final class LauncherLifecycleStore {
	var state: LauncherState
	let log: LauncherLog

	var activity: LauncherActivity {
		get { state.activity }
		set { state.activity = newValue }
	}

	var refresh: LauncherRefreshState {
		get { state.refresh }
		set { state.refresh = newValue }
	}

	var readiness: LauncherReadinessState {
		get { state.readiness }
		set { state.readiness = newValue }
	}

	var presentation: LauncherPresentationState {
		get { state.presentation }
		set { state.presentation = newValue }
	}

	var intelTranslationState: IntelTranslationState {
		get { state.readiness.intelTranslation }
		set { state.readiness.intelTranslation = newValue }
	}

	var rosettaInstallationState: RosettaInstallationState {
		get { state.readiness.rosettaInstallation }
		set { state.readiness.rosettaInstallation = newValue }
	}

	var activityMessage: String { state.presentation.status.message }
	var failureMessage: String? { state.presentation.failureMessage }
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

	init(
		state: LauncherState = LauncherState(),
		log: LauncherLog
	) {
		self.state = state
		self.log = log
	}

	func setStatus(_ status: LauncherStatus, clearsFailure: Bool = true) {
		state.presentation.status = status
		if clearsFailure { state.presentation.failureMessage = nil }
	}

	func clearFailure() {
		state.presentation.failureMessage = nil
	}

	func show(_ error: any Error, context: String? = nil) {
		let message = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
		state.presentation.failureMessage = message
		let diagnostic = launcherDiagnosticDescription(for: error)
		let logMessage = context.map { "\($0): \(diagnostic)" } ?? diagnostic
		Task { [log] in await log.error(logMessage) }
	}
}
