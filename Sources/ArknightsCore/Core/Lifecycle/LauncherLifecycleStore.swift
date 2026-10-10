// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

/// Owns launcher state that spans otherwise independent features. Feature controllers use this
/// store for mutually exclusive activity and user-facing presentation, but never depend on the
/// root composition model.
@MainActor
@Observable
package final class LauncherLifecycleStore {
	var state: LauncherState
	package let log: LauncherLog
	package private(set) var isLauncherUpdatePending = false
	private var activityObservers: [UUID: () -> Void] = [:]
	private var currentLease: ActivityLease?

	package var activity: LauncherActivity {
		if isLauncherUpdatePending, state.activity == .idle {
			return .maintaining(.updatingLauncher)
		}
		return state.activity
	}

	private func applyActivity(_ newValue: LauncherActivity) {
		guard state.activity != newValue else { return }
		state.activity = newValue
		for observer in Array(activityObservers.values) {
			observer()
		}
	}

	/// Claims the exclusive activity. Returns nil while another activity or a launcher update runs.
	package func begin(_ activity: LauncherActivity) -> ActivityLease? {
		guard canBeginExclusiveActivity else { return nil }
		let lease = ActivityLease()
		currentLease = lease
		applyActivity(activity)
		return lease
	}

	/// Changes the activity for the lease holder. A stale lease changes nothing and returns false.
	@discardableResult
	package func update(_ lease: ActivityLease, to activity: LauncherActivity) -> Bool {
		guard currentLease == lease else { return false }
		applyActivity(activity)
		return true
	}

	/// Releases the activity for the lease holder. A stale lease changes nothing and returns false.
	@discardableResult
	package func end(_ lease: ActivityLease) -> Bool {
		guard currentLease == lease else { return false }
		currentLease = nil
		applyActivity(.idle)
		return true
	}

	#if DEBUG
		/// Sets the activity without a lease and invalidates any lease. For developer simulation and tests.
		package func simulateActivity(_ activity: LauncherActivity) {
			currentLease = nil
			applyActivity(activity)
		}
	#endif

	/// The underlying activity excludes the Sparkle update gate itself.
	package var hasActiveActivity: Bool { state.activity != .idle }
	package var canBeginExclusiveActivity: Bool { !hasActiveActivity && !isLauncherUpdatePending }

	package var refresh: LauncherRefreshState {
		get { state.refresh }
		set { state.refresh = newValue }
	}

	package var readiness: LauncherReadinessState {
		get { state.readiness }
		set { state.readiness = newValue }
	}

	package var presentation: LauncherPresentationState {
		get { state.presentation }
		set { state.presentation = newValue }
	}

	package var intelTranslationState: IntelTranslationState {
		get { state.readiness.intelTranslation }
		set { state.readiness.intelTranslation = newValue }
	}

	package var rosettaInstallationState: RosettaInstallationState {
		get { state.readiness.rosettaInstallation }
		set { state.readiness.rosettaInstallation = newValue }
	}

	package var activityMessage: String { state.presentation.status.message }
	package var failure: LauncherFailurePresentation? { state.presentation.failure }
	package var failureMessage: String? { state.presentation.failure?.message }
	package var phase: LauncherPhase {
		switch state.activity {
		case .installing:
			.downloading
		case .preparingGame:
			.migrating
		case .launchingGame:
			.launching
		case .runningGame(_, let processIdentifier):
			.running(processIdentifier: processIdentifier)
		case .stoppingGame(_, let processIdentifier):
			processIdentifier.map { .running(processIdentifier: $0) } ?? .launching
		case .idle, .maintaining:
			state.refresh.isChecking ? .checking : .ready
		}
	}

	package init(
		state: LauncherState = LauncherState(),
		log: LauncherLog
	) {
		self.state = state
		self.log = log
	}

	package func setStatus(_ status: LauncherStatus, clearsFailure: Bool = true) {
		state.presentation.status = status
		if clearsFailure,
			state.presentation.failure?.context.operation != .intelTranslationPreflight
		{
			state.presentation.failure = nil
		}
	}

	package func clearFailure() {
		state.presentation.failure = nil
	}

	package func beginLauncherUpdate() {
		isLauncherUpdatePending = true
	}

	package func finishLauncherUpdate() {
		isLauncherUpdatePending = false
	}

	@discardableResult
	package func observeActivityChanges(_ observer: @escaping () -> Void) -> UUID {
		let id = UUID()
		activityObservers[id] = observer
		return id
	}

	package func removeActivityObserver(_ id: UUID) {
		activityObservers[id] = nil
	}

	package func show(
		_ error: any Error,
		context: String? = nil,
		blocksGameLaunch: Bool = false
	) {
		let message = launcherUserMessage(for: error)
		let code = Self.supportCode(for: error)
		let failure = LauncherFailurePresentation(
			id: UUID(), message: message, code: code,
			context: SupportContext(operation: .launcher, region: nil),
			actions: code == nil ? [.reportProblem] : [.openTroubleshooting, .reportProblem],
			blocksGameLaunch: blocksGameLaunch
		)
		let diagnostic = launcherDiagnosticDescription(for: error)
		let logMessage = context.map { "\($0): \(diagnostic)" } ?? diagnostic
		presentFailure(failure, diagnostic: logMessage)
	}

	private static func supportCode(for error: any Error) -> SupportCode? {
		switch error {
		case let provider as any SupportCodeProviding:
			provider.supportCode
		case is CocoaError, is POSIXError:
			.basalt
		default:
			nil
		}
	}

	@discardableResult
	package func presentFailure(
		_ failure: LauncherFailurePresentation,
		diagnostic: String
	) -> Bool {
		if state.presentation.failure?.id == failure.id {
			log.error(
				"Failure not presented; code=\(failure.code?.rawValue ?? "none") operation=\(failure.context.operation.rawValue) diagnostic=\(diagnostic)"
			)
			return false
		}
		state.presentation.failure = failure
		log.error(
			"Failure presented; code=\(failure.code?.rawValue ?? "none") operation=\(failure.context.operation.rawValue) diagnostic=\(diagnostic)"
		)
		return true
	}

	@discardableResult
	package func consumeFailure(id: UUID) -> LauncherFailurePresentation? {
		guard state.presentation.failure?.id == id else { return nil }
		defer { state.presentation.failure = nil }
		return state.presentation.failure
	}
}
