// SPDX-License-Identifier: MPL-2.0

import Foundation
import Sparkle

/// Owns Sparkle's update engine and prevents replacement during launcher activity.
@MainActor
final class LauncherUpdaterController: NSObject, SPUUpdaterDelegate {
	let userDriver: LauncherUpdateUserDriver

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
	private enum CheckKind {
		case none
		case probe
		case userInitiated
	}
	private var checkKind = CheckKind.none
	private var probeOutcome: LauncherUpdateCheckOutcome = .current
	private var probeCompletion: ((LauncherUpdateCheckOutcome) -> Void)?

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
		guard checkKind == .none, updater.canCheckForUpdates, !updater.sessionInProgress else {
			return
		}
		checkKind = .userInitiated
		updater.checkForUpdates()
	}

	func checkForUpdateInformation(
		completion: @escaping (LauncherUpdateCheckOutcome) -> Void
	) {
		guard lifecycle.canBeginExclusiveActivity, checkKind == .none else {
			completion(.failed)
			return
		}
		checkKind = .probe
		probeOutcome = .current
		probeCompletion = completion
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
			checkKind = .probe
			probeOutcome = .current
			probeCompletion = completion
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
		if checkKind == .probe {
			probeOutcome = .updateAvailable(item.displayVersionString)
		}
	}

	func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
		if checkKind == .probe {
			probeOutcome = .current
			return
		}
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
		if checkKind == .probe {
			let outcome: LauncherUpdateCheckOutcome
			if let error {
				outcome = Self.isNoUpdateError(error) ? .current : .failed
			} else {
				outcome = probeOutcome
			}
			completeProbe(outcome)
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
			Task { await self.log.info("Resuming postponed launcher update installation") }
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
		if checkKind == .probe {
			// Sparkle calls didAbort before didFinish for a probe that ends in an
			// error. Keep the completion pending until the update cycle finishes.
			probeOutcome = Self.isNoUpdateError(error) ? .current : .failed
			return
		}
		finishLauncherUpdate()
	}

	private func finishLauncherUpdate() {
		if let postponedActivityObserverID {
			lifecycle.removeActivityObserver(postponedActivityObserverID)
			self.postponedActivityObserverID = nil
		}
		checkKind = .none
		lifecycle.finishLauncherUpdate()
	}

	private func completeProbe(_ outcome: LauncherUpdateCheckOutcome) {
		guard checkKind == .probe else { return }
		checkKind = .none
		let completion = probeCompletion
		probeCompletion = nil
		completion?(outcome)
	}

	static func isNoUpdateError(_ error: Error) -> Bool {
		let error = error as NSError
		return error.domain == SUSparkleErrorDomain
			&& error.code == Int(SUError.noUpdateError.rawValue)
	}

	private static let busyError = NSError(
		domain: "ArknightsClient.LauncherUpdater",
		code: 1,
		userInfo: [NSLocalizedDescriptionKey: L10n.string(.Launcher.launcherUpdateBusy)]
	)
}
