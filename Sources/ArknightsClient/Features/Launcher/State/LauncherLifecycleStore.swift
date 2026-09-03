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
	private(set) var isLauncherUpdatePending = false
	private var activityObservers: [UUID: () -> Void] = [:]

	var activity: LauncherActivity {
		get {
			if isLauncherUpdatePending, state.activity == .idle {
				return .maintaining(.updatingLauncher)
			}
			return state.activity
		}
		set {
			guard state.activity != newValue else { return }
			state.activity = newValue
			for observer in Array(activityObservers.values) {
				observer()
			}
		}
	}

	/// The underlying activity excludes the Sparkle update gate itself.
	var hasActiveActivity: Bool { state.activity != .idle }
	var canBeginExclusiveActivity: Bool { !hasActiveActivity && !isLauncherUpdatePending }

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
	var failure: LauncherFailurePresentation? { state.presentation.failure }
	var failureMessage: String? { state.presentation.failure?.message }
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
		if clearsFailure { state.presentation.failure = nil }
	}

	func clearFailure() {
		state.presentation.failure = nil
	}

	func beginLauncherUpdate() {
		isLauncherUpdatePending = true
	}

	func finishLauncherUpdate() {
		isLauncherUpdatePending = false
	}

	@discardableResult
	func observeActivityChanges(_ observer: @escaping () -> Void) -> UUID {
		let id = UUID()
		activityObservers[id] = observer
		return id
	}

	func removeActivityObserver(_ id: UUID) {
		activityObservers[id] = nil
	}

	func show(
		_ error: any Error,
		context: String? = nil,
		blocksGameLaunch: Bool = false
	) {
		let message = launcherUserMessage(for: error)
		let failure = LauncherFailurePresentation(
			id: UUID(), message: message, code: nil,
			context: SupportContext(operation: .launcher, region: nil),
			actions: [.reportProblem],
			blocksGameLaunch: blocksGameLaunch
		)
		let diagnostic = launcherDiagnosticDescription(for: error)
		let logMessage = context.map { "\($0): \(diagnostic)" } ?? diagnostic
		presentFailure(failure, diagnostic: logMessage)
	}

	@discardableResult
	func presentFailure(
		_ failure: LauncherFailurePresentation,
		diagnostic: String
	) -> Bool {
		if state.presentation.failure?.id == failure.id {
			Task { [log] in
				await log.error(
					"Failure not presented; code=\(failure.code?.rawValue ?? "none") operation=\(failure.context.operation.rawValue) diagnostic=\(diagnostic)"
				)
			}
			return false
		}
		state.presentation.failure = failure
		Task { [log] in
			await log.error(
				"Failure presented; code=\(failure.code?.rawValue ?? "none") operation=\(failure.context.operation.rawValue) diagnostic=\(diagnostic)"
			)
		}
		return true
	}

	@discardableResult
	func consumeFailure(id: UUID) -> LauncherFailurePresentation? {
		guard state.presentation.failure?.id == id else { return nil }
		defer { state.presentation.failure = nil }
		return state.presentation.failure
	}
}
