// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
internal import Sparkle

/// Owns Sparkle's update engine and prevents replacement during launcher activity.
@MainActor
package final class LauncherUpdaterController: NSObject, SPUUpdaterDelegate {
	let userDriver: LauncherUpdateUserDriver
	package private(set) var installationID: UUID?

	private let lifecycle: LauncherLifecycleStore
	private let log: LauncherLog
	private lazy var updater = SPUUpdater(
		hostBundle: .main,
		applicationBundle: .main,
		userDriver: userDriver,
		delegate: self
	)
	private var hasStarted = false
	private var postponedActivityObserverID: UUID?
	private var cancelActivityObservation: (@Sendable () -> Void)?
	private enum Check {
		case userInitiated
		// A silent availability check; Sparkle reports its outcome across several callbacks.
		case probe(LauncherUpdateCheckOutcome, completion: (LauncherUpdateCheckOutcome) -> Void)
	}
	private var check: Check?
	private var updateFailureID: UUID?

	init(
		lifecycle: LauncherLifecycleStore,
		log: LauncherLog,
		activateApplication: @escaping () -> Void =
			{ LauncherUpdateUserDriver.activateApplicationInFront() }
	) {
		self.lifecycle = lifecycle
		self.log = log
		let driver = LauncherUpdateUserDriver(
			activateApplication: activateApplication,
			canRetryTermination: { [weak lifecycle] in
				lifecycle?.hasActiveActivity == false
			},
			isGameRunning: { [weak lifecycle] in
				lifecycle?.activity.isGameActive == true
			}
		)
		userDriver = driver
		super.init()
		driver.reportFailure = { [weak self] error in self?.reportUpdateFailure(error) ?? false }
		let activityObserverID = lifecycle.observeActivityChanges { [weak driver] in
			driver?.retryTerminationIfSafe()
		}
		cancelActivityObservation = { [lifecycle] in
			Task { @MainActor in lifecycle.removeActivityObserver(activityObserverID) }
		}
	}

	deinit {
		cancelActivityObservation?()
	}

	var canOpenUpdate: Bool {
		userDriver.phase != .hidden || lifecycle.canBeginExclusiveActivity
	}

	var hasActiveUpdate: Bool { userDriver.phase != .hidden }
	package var canTerminateForUpdate: Bool {
		installationID != nil && lifecycle.isLauncherUpdatePending
			&& !lifecycle.hasActiveActivity
			&& userDriver.phase != .failed && userDriver.phase != .hidden
	}

	func checkForUpdates() {
		if userDriver.phase != .hidden && !userDriver.isPresented {
			userDriver.showUpdateInFocus()
			return
		}
		guard lifecycle.canBeginExclusiveActivity, startIfNeeded(showError: true) else { return }
		if userDriver.isPresented {
			updater.checkForUpdates()
			return
		}
		guard check == nil, updater.canCheckForUpdates, !updater.sessionInProgress else {
			return
		}
		check = .userInitiated
		updater.checkForUpdates()
	}

	func checkForUpdateInformation(
		completion: @escaping (LauncherUpdateCheckOutcome) -> Void
	) {
		guard lifecycle.canBeginExclusiveActivity, check == nil else {
			completion(.failed)
			return
		}
		check = .probe(.current, completion: completion)
		guard startIfNeeded(showError: false), updater.canCheckForUpdates,
			!updater.sessionInProgress
		else {
			completeProbe(.failed)
			return
		}
		updater.checkForUpdateInformation()
	}

	#if DEBUG
		func beginProbeForTesting(
			completion: @escaping (LauncherUpdateCheckOutcome) -> Void
		) {
			check = .probe(.current, completion: completion)
		}
	#endif

	private func startIfNeeded(showError: Bool) -> Bool {
		guard !hasStarted else { return true }
		do {
			try updater.start()
		} catch {
			if showError { userDriver.showError(error) }
			return false
		}
		hasStarted = true
		return true
	}

	func updater(
		_ updater: SPUUpdater,
		mayPerform updateCheck: SPUUpdateCheck
	) throws {
		guard lifecycle.canBeginExclusiveActivity else {
			throw Self.busyError
		}
	}

	func updater(
		_ updater: SPUUpdater,
		shouldProceedWithUpdate updateItem: SUAppcastItem,
		updateCheck: SPUUpdateCheck
	) throws {
		guard lifecycle.canBeginExclusiveActivity else {
			throw Self.busyError
		}
	}

	func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
		userDriver.recordAvailableUpdate(item)
		recordProbeOutcome(
			.found(version: item.displayVersionString, running: Bundle.main.shortVersionString))
	}

	func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
		if recordProbeOutcome(.current) { return }
		userDriver.recordNoUpdate(error)
	}

	func updater(
		_ updater: SPUUpdater,
		didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
		error: Error?
	) {
		guard updateCheck == .updateInformation else {
			finishLauncherUpdate()
			return
		}
		if case .probe(let recorded, _) = check {
			completeProbe(error.map { Self.probeOutcome(for: $0) } ?? recorded)
			return
		}
		if let error {
			userDriver.recordAvailabilityError(error)
		} else {
			userDriver.finishInformationCheck()
		}
	}

	func updaterShouldRelaunchApplication(_ updater: SPUUpdater) -> Bool {
		true
	}

	func updater(
		_ updater: SPUUpdater,
		userDidMake choice: SPUUserUpdateChoice,
		forUpdate updateItem: SUAppcastItem,
		state: SPUUserUpdateState
	) {
		if choice == .install || state.stage != .notDownloaded || lifecycle.isLauncherUpdatePending
		{
			lifecycle.beginLauncherUpdate()
		}
	}

	func updater(
		_ updater: SPUUpdater,
		willInstallUpdate item: SUAppcastItem
	) {
		lifecycle.beginLauncherUpdate()
		// Sparkle can send its quit event before the user driver reaches .installing.
		if installationID == nil { installationID = UUID() }
	}

	func updater(
		_ updater: SPUUpdater,
		willInstallUpdateOnQuit item: SUAppcastItem,
		immediateInstallationBlock _: @escaping () -> Void
	) -> Bool {
		false
	}

	func updater(
		_ updater: SPUUpdater,
		shouldPostponeRelaunchForUpdate item: SUAppcastItem,
		untilInvokingBlock installHandler: @escaping () -> Void
	) -> Bool {
		guard lifecycle.hasActiveActivity else { return false }
		if let postponedActivityObserverID {
			lifecycle.removeActivityObserver(postponedActivityObserverID)
		}
		var observerID: UUID?
		observerID = lifecycle.observeActivityChanges { [weak self] in
			guard let self, !self.lifecycle.hasActiveActivity else { return }
			if let observerID { self.lifecycle.removeActivityObserver(observerID) }
			self.postponedActivityObserverID = nil
			installHandler()
			self.log.info("Resuming postponed launcher update installation")
		}
		postponedActivityObserverID = observerID
		return true
	}

	func updater(
		_ updater: SPUUpdater,
		failedToDownloadUpdate item: SUAppcastItem,
		error: Error
	) {
		finishLauncherUpdate()
	}

	func userDidCancelDownload(_ updater: SPUUpdater) {
		finishLauncherUpdate()
	}

	func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
		// Sparkle calls didAbort before didFinish for a probe that ends in an
		// error. Keep the completion pending until the update cycle finishes.
		if !Self.isNoUpdateError(error) {
			log.error("Launcher update aborted: \(error)")
		}
		if recordProbeOutcome(Self.probeOutcome(for: error)) { return }
		finishLauncherUpdate()
	}

	/// Logs every update failure. A user-started check or install hands the failure to the
	/// failure sheet and returns true, so the overlay stays idle. Background and probe failures
	/// return false and keep their inline message.
	private func reportUpdateFailure(_ error: any Error) -> Bool {
		log.error("Launcher update failed: \(error)")
		guard installationID != nil || isUserInitiatedCheck else { return false }
		// Keep the failure the user already sees. A second one would replace it.
		guard lifecycle.state.presentation.failure == nil else { return true }
		let failureID = UUID()
		updateFailureID = failureID
		lifecycle.presentFailure(
			ContextualLauncherError(
				userMessage: LauncherUpdateUserDriver.errorDetail,
				diagnosticDescription: String(describing: error),
				supportCode: .updateFailed
			),
			id: failureID,
			code: .updateFailed,
			context: SupportContext(operation: .launcher, region: nil),
			canRepair: false,
			allowsRetry: true,
			blocksGameLaunch: false
		)
		return true
	}

	/// Starts a new user-initiated check for the update failure `id`. Returns false when `id`
	/// is not the failure the sheet shows.
	package func retryFailure(id: UUID) -> Bool {
		guard updateFailureID == id, lifecycle.canBeginExclusiveActivity,
			lifecycle.consumeFailure(id: id) != nil
		else { return false }
		updateFailureID = nil
		log.info("Recovery selected; action=retry operation=launcher-update")
		checkForUpdates()
		return true
	}

	private var isUserInitiatedCheck: Bool {
		if case .userInitiated = check { return true }
		return false
	}

	private func finishLauncherUpdate() {
		installationID = nil
		if let postponedActivityObserverID {
			lifecycle.removeActivityObserver(postponedActivityObserverID)
			self.postponedActivityObserverID = nil
		}
		check = nil
		lifecycle.finishLauncherUpdate()
	}

	@discardableResult
	private func recordProbeOutcome(_ outcome: LauncherUpdateCheckOutcome) -> Bool {
		guard case .probe(_, let completion) = check else { return false }
		check = .probe(outcome, completion: completion)
		return true
	}

	private func completeProbe(_ outcome: LauncherUpdateCheckOutcome) {
		guard case .probe(_, let completion) = check else { return }
		check = nil
		completion(outcome)
	}

	private static func probeOutcome(for error: Error) -> LauncherUpdateCheckOutcome {
		isNoUpdateError(error) ? .current : .failed
	}

	static func isNoUpdateError(_ error: Error) -> Bool {
		let error = error as NSError
		return error.domain == SUSparkleErrorDomain
			&& error.code == Int(SUError.noUpdateError.rawValue)
	}

	private static let busyError = NSError(
		domain: "ArknightsClient.LauncherUpdater",
		code: 1,
		userInfo: [
			NSLocalizedDescriptionKey:
				"Launcher updates are unavailable during an active operation."
		]
	)
}
