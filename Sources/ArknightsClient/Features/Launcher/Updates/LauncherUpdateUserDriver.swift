// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Observation
import Sparkle

enum LauncherUpdatePhase: Equatable {
	case hidden
	case checking
	case available
	case downloading
	case extracting
	case readyToInstall
	case installing
	case installed
	case noUpdate
	case failed
}

/// Bridges Sparkle's callbacks to the launcher's one custom update presentation.
@MainActor
@Observable
final class LauncherUpdateUserDriver: NSObject, SPUUserDriver {
	private(set) var phase: LauncherUpdatePhase = .hidden
	private(set) var version: String?
	private(set) var releaseNotes: String?
	private(set) var releaseNotesFormat: String?
	private(set) var updateStage: SPUUserUpdateStage?
	private(set) var informationOnly = false
	private(set) var informationURL: URL?
	private(set) var expectedBytes: UInt64 = 0
	private(set) var receivedBytes: UInt64 = 0
	private(set) var extractionProgress: Double = 0
	private(set) var applicationTerminated = false
	private(set) var gameIsRunning = false
	private(set) var terminationBlocked = false
	private(set) var relaunched = false
	private(set) var message: String?

	@ObservationIgnored private var updateReply: ((SPUUserUpdateChoice) -> Void)?
	@ObservationIgnored private var readyReply: ((SPUUserUpdateChoice) -> Void)?
	@ObservationIgnored private var noUpdateAcknowledgement: (() -> Void)?
	@ObservationIgnored private var errorAcknowledgement: (() -> Void)?
	@ObservationIgnored private var installedAcknowledgement: (() -> Void)?
	@ObservationIgnored private var checkCancellation: (() -> Void)?
	@ObservationIgnored private var downloadCancellation: (() -> Void)?
	@ObservationIgnored private var retryTermination: (() -> Void)?
	@ObservationIgnored private var automaticTerminationTask: Task<Void, Never>?
	private var automaticRetryAttempted = false
	private var isPresentationHidden = false
	private let activateApplication: () -> Void
	private let canRetryTermination: () -> Bool
	private let gameRunningProvider: () -> Bool
	private let automaticRetryScheduler: (@escaping @MainActor () -> Void) -> Task<Void, Never>

	static func activateApplicationInFront() {
		NSApp.activate(ignoringOtherApps: true)
		(NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible))?.makeKeyAndOrderFront(nil)
	}

	init(
		activateApplication: @escaping () -> Void =
			{ LauncherUpdateUserDriver.activateApplicationInFront() },
		canRetryTermination: @escaping () -> Bool = { true },
		isGameRunning: @escaping () -> Bool = { false },
		automaticRetryScheduler: @escaping (@escaping @MainActor () -> Void) -> Task<Void, Never> =
			{
				action in
				Task { @MainActor in
					await Task.yield()
					guard !Task.isCancelled else { return }
					action()
				}
			}
	) {
		self.activateApplication = activateApplication
		self.canRetryTermination = canRetryTermination
		self.gameRunningProvider = isGameRunning
		self.automaticRetryScheduler = automaticRetryScheduler
		super.init()
	}

	deinit {
		automaticTerminationTask?.cancel()
	}
	var isPresented: Bool { phase != .hidden && !isPresentationHidden }
	func show(
		_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void
	) {
		reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
	}
	func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
		resetCallbacks()
		version = nil
		releaseNotes = nil
		releaseNotesFormat = nil
		updateStage = nil
		informationOnly = false
		informationURL = nil
		expectedBytes = 0
		receivedBytes = 0
		extractionProgress = 0
		phase = .checking
		message = nil
		checkCancellation = cancellation
	}
	func showUpdateFound(
		with appcastItem: SUAppcastItem,
		state: SPUUserUpdateState,
		reply: @escaping (SPUUserUpdateChoice) -> Void
	) {
		resetCallbacks()
		setUpdateDetails(appcastItem)
		updateStage = state.stage
		expectedBytes = 0
		receivedBytes = 0
		extractionProgress = 0
		phase = .available
		updateReply = reply
	}
	func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
		releaseNotes = String(data: downloadData.data, encoding: .utf8)
		releaseNotesFormat = downloadData.mimeType == "text/plain" ? "plain-text" : "html"
	}
	func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {
		message = L10n.string(LauncherStrings.updateReleaseNotesUnavailable)
	}
	func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
		resetCallbacks()
		phase = .noUpdate
		message = L10n.string(LauncherStrings.updateErrorDetail)
		noUpdateAcknowledgement = acknowledgement
	}
	func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
		resetCallbacks()
		showError(error)
		errorAcknowledgement = acknowledgement
	}
	func showDownloadInitiated(cancellation: @escaping () -> Void) {
		cancelAutomaticTerminationRetry()
		phase = .downloading
		receivedBytes = 0
		downloadCancellation = cancellation
	}
	func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
		expectedBytes = expectedContentLength
	}
	func showDownloadDidReceiveData(ofLength length: UInt64) {
		let (total, overflow) = receivedBytes.addingReportingOverflow(length)
		receivedBytes = overflow ? .max : total
	}
	func showDownloadDidStartExtractingUpdate() {
		cancelAutomaticTerminationRetry()
		phase = .extracting
		extractionProgress = 0
		downloadCancellation = nil
	}
	func showExtractionReceivedProgress(_ progress: Double) {
		cancelAutomaticTerminationRetry()
		phase = .extracting
		extractionProgress = min(max(progress, 0), 1)
	}
	func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
		cancelAutomaticTerminationRetry()
		phase = .readyToInstall
		readyReply = reply
	}
	func showInstallingUpdate(
		withApplicationTerminated applicationTerminated: Bool,
		retryTerminatingApplication: @escaping () -> Void
	) {
		resetCallbacks()
		phase = .installing
		self.applicationTerminated = applicationTerminated
		refreshTerminationContext()
		retryTermination = applicationTerminated ? nil : retryTerminatingApplication
		self.message = nil
		if !applicationTerminated { scheduleAutomaticTerminationRetry() }
	}
	func showUpdateInstalledAndRelaunched(
		_ relaunched: Bool,
		acknowledgement: @escaping () -> Void
	) {
		cancelAutomaticTerminationRetry()
		retryTermination = nil
		if relaunched {
			hide()
			acknowledgement()
			return
		}
		phase = .installed
		self.relaunched = relaunched
		installedAcknowledgement = acknowledgement
	}
	func dismissUpdateInstallation() {
		resetCallbacks()
		phase = .hidden
	}
	func showUpdateInFocus() {
		guard phase != .hidden else { return }
		isPresentationHidden = false
		activateApplication()
	}
	func choose(_ choice: SPUUserUpdateChoice) {
		guard choice != .skip else { return }
		let actualChoice = informationOnly && choice == .install ? .dismiss : choice
		if let reply = takeReply(&updateReply) {
			if actualChoice != .install { hide() }
			reply(actualChoice)
		} else if let reply = takeReply(&readyReply) {
			if actualChoice != .install { hide() }
			reply(actualChoice)
		}
	}
	func cancelCheck() {
		guard let cancellation = takeAction(&checkCancellation) else { return }
		hide()
		cancellation()
	}
	func cancelDownload() {
		guard let cancellation = takeAction(&downloadCancellation) else { return }
		hide()
		cancellation()
	}
	func acknowledge() {
		if let acknowledgement = takeAction(&noUpdateAcknowledgement) {
			hide()
			acknowledgement()
		} else if let acknowledgement = takeAction(&errorAcknowledgement) {
			hide()
			acknowledgement()
		} else if let acknowledgement = takeAction(&installedAcknowledgement) {
			hide()
			acknowledgement()
		}
	}
	func retryTerminationRequest() {
		guard phase == .installing, let retryTermination else { return }
		refreshTerminationContext()
		retryTermination()
	}
	/// Called by the lifecycle controller when an active game or installation becomes idle.
	func retryTerminationIfSafe() {
		guard phase == .installing, !applicationTerminated, !automaticRetryAttempted,
			let retryTermination
		else { return }
		refreshTerminationContext()
		guard !terminationBlocked else { return }
		automaticRetryAttempted = true
		automaticTerminationTask = nil
		retryTermination()
	}
	func dismissFromUser() {
		// Installing has no Later button to mimic, and hiding rather than cancelling avoids
		// interrupting an in-progress install from a stray Escape press, while letting the
		// launcher's update indicator reopen this exact presentation later. Every other phase
		// (including readyToInstall) falls through below to reply exactly as Later would.
		if phase == .installing {
			isPresentationHidden = true
			return
		}
		if let reply = takeReply(&updateReply) {
			hide()
			reply(.dismiss)
		} else if let reply = takeReply(&readyReply) {
			hide()
			reply(.dismiss)
		} else if let cancellation = takeAction(&checkCancellation) {
			hide()
			cancellation()
		} else if let cancellation = takeAction(&downloadCancellation) {
			hide()
			cancellation()
		} else {
			acknowledge()
		}
	}
	func showError(_ error: Error) {
		cancelAutomaticTerminationRetry()
		phase = .failed
		message = L10n.string(LauncherStrings.updateErrorDetail)
		if errorAcknowledgement == nil {
			errorAcknowledgement = {}
		}
	}
	private func setUpdateDetails(_ item: SUAppcastItem) {
		version = item.displayVersionString
		releaseNotes = item.itemDescription
		releaseNotesFormat = item.itemDescriptionFormat
		informationOnly = item.isInformationOnlyUpdate
		informationURL = item.infoURL
	}
	private func refreshTerminationContext() {
		gameIsRunning = !applicationTerminated && gameRunningProvider()
		terminationBlocked = !applicationTerminated && !gameIsRunning && !canRetryTermination()
	}
	func finishInformationCheck() {
		if phase == .checking {
			isPresentationHidden = false
			phase = .hidden
		}
	}
	func recordAvailableUpdate(_ item: SUAppcastItem) {
		setUpdateDetails(item)
	}
	func recordNoUpdate(_ error: Error) {
		if phase == .hidden || phase == .checking { phase = .noUpdate }
		message = L10n.string(LauncherStrings.updateErrorDetail)
	}
	func recordAvailabilityError(_ error: Error) {
		if phase == .hidden || phase == .checking { showError(error) }
	}
	private func resetCallbacks() {
		cancelAutomaticTerminationRetry()
		updateReply = nil
		readyReply = nil
		noUpdateAcknowledgement = nil
		errorAcknowledgement = nil
		installedAcknowledgement = nil
		checkCancellation = nil
		downloadCancellation = nil
		retryTermination = nil
		isPresentationHidden = false
	}
	private func hide() {
		resetCallbacks()
		phase = .hidden
	}
	private func scheduleAutomaticTerminationRetry() {
		automaticRetryAttempted = false
		automaticTerminationTask?.cancel()
		automaticTerminationTask = automaticRetryScheduler { [weak self] in
			self?.retryTerminationIfSafe()
		}
	}

	private func cancelAutomaticTerminationRetry() {
		automaticTerminationTask?.cancel()
		automaticTerminationTask = nil
		automaticRetryAttempted = false
	}
	private func takeAction(_ callback: inout (() -> Void)?) -> (() -> Void)? {
		defer { callback = nil }
		return callback
	}
	private func takeReply(
		_ callback: inout ((SPUUserUpdateChoice) -> Void)?
	) -> ((SPUUserUpdateChoice) -> Void)? {
		defer { callback = nil }
		return callback
	}
}
