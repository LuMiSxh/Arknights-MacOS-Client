// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Observation

/// Owns launcher updates, announcements, Yostar notices, and their shared popup queue.
@MainActor
@Observable
final class LauncherCommunicationController {
	var launcherUpdateVersion: String?
	var launcherUpdateStatus: String?
	var isCheckingLauncherUpdates = false
	var popup: LauncherPopup?
	var canOpenLauncherUpdate: Bool { launcherUpdater.canOpenUpdate }
	var shouldShowLauncherUpdateButton: Bool {
		launcherUpdateVersion != nil || launcherUpdater.hasActiveUpdate
	}

	private let announcementService: LauncherAnnouncementService
	private let preferences: LauncherPreferencesStore
	private let log: LauncherLog
	private let launcherUpdater: LauncherUpdaterController
	private var pendingPopups: [LauncherPopup] = []
	private var presentedNoticeContent: String?
	@ObservationIgnored private var launcherUpdateTask: Task<LauncherUpdateCheckOutcome, Never>?
	@ObservationIgnored private var announcementTask: Task<Void, Never>?
	private var startupProbeOutcome: LauncherUpdateCheckOutcome?

	init(
		lifecycle: LauncherLifecycleStore,
		announcementService: LauncherAnnouncementService,
		preferences: LauncherPreferencesStore,
		log: LauncherLog
	) {
		self.announcementService = announcementService
		self.preferences = preferences
		self.log = log
		let updater = LauncherUpdaterController(lifecycle: lifecycle, log: log)
		self.launcherUpdater = updater
	}

	deinit {
		launcherUpdateTask?.cancel()
		announcementTask?.cancel()
	}

	@discardableResult
	func checkLauncherUpdates(presentUpdate: Bool = false)
		-> Task<LauncherUpdateCheckOutcome, Never>
	{
		let task = startLauncherUpdateCheck()
		guard presentUpdate else { return task }
		return Task { [weak self] in
			let outcome = await task.value
			guard let self else { return outcome }
			startupProbeOutcome = outcome
			if case .updateAvailable = outcome {
				launcherUpdater.checkForUpdates()
			}
			return outcome
		}
	}

	/// Reuses an active request so onboarding and the automatic check cannot race.
	func launcherUpdateCheckForOnboarding() async -> LauncherUpdateCheckOutcome {
		if let startupProbeOutcome {
			self.startupProbeOutcome = nil
			return startupProbeOutcome
		}
		return await startLauncherUpdateCheck().value
	}

	func openLauncherUpdate() {
		launcherUpdater.checkForUpdates()
	}

	var launcherUpdateUserDriver: LauncherUpdateUserDriver {
		launcherUpdater.userDriver
	}

	func checkAnnouncements(isEnabled: Bool) {
		guard isEnabled else { return }
		guard
			let endpointString = Bundle.main.object(
				forInfoDictionaryKey: "LauncherAnnouncementsURL"
			) as? String,
			let endpoint = URL(string: endpointString)
		else { return }

		announcementTask?.cancel()
		announcementTask = Task { [weak self] in
			guard let self else { return }
			do {
				let announcements = try await announcementService.announcements(from: endpoint)
				let currentVersion = Bundle.main.shortVersionString ?? "0"
				let seenIDs = preferences.seenAnnouncementIDs()
				guard
					let announcement = announcements.first(where: {
						$0.isEligible(
							currentVersion: currentVersion,
							now: .now,
							seenIDs: seenIDs
						)
					})
				else { return }
				enqueuePopup(
					LauncherPopup(
						id: "announcement-\(announcement.id)",
						title: announcement.title,
						content: .markdown(announcement.body),
						dismissTitle: L10n.string(LauncherStrings.popupDone),
						actionTitle: announcement.actionTitle,
						actionURL: announcement.actionURL
					)
				)
				await log.info("Announcement presented; id=\(announcement.id)")
			} catch is CancellationError {
				return
			} catch {
				await log.error("Announcement check failed: \(error.localizedDescription)")
			}
		}
	}

	func presentNoticeIfNeeded(_ branding: LauncherBranding) {
		guard
			branding.noticePopOpen == true,
			let content = branding.noticeContent,
			content != presentedNoticeContent,
			let formattedNotice = LauncherNoticeFormatter.notice(fromHTML: content)
		else { return }
		presentedNoticeContent = content
		enqueuePopup(
			LauncherPopup(
				id: "yostar-notice-\(formattedNotice.id.uuidString)",
				title: L10n.string(LauncherStrings.popupNotice),
				content: .attributed(formattedNotice.content),
				dismissTitle: L10n.string(LauncherStrings.popupDone),
				actionTitle: nil,
				actionURL: nil
			)
		)
	}

	func resetPresentedNotice() {
		presentedNoticeContent = nil
	}

	func enqueuePopup(_ newPopup: LauncherPopup) {
		guard popup?.id != newPopup.id,
			!pendingPopups.contains(where: { $0.id == newPopup.id })
		else { return }
		if popup == nil {
			popup = newPopup
			recordPopupPresentation(newPopup)
		} else {
			pendingPopups.append(newPopup)
		}
	}

	func dismissPopup() {
		popup = pendingPopups.isEmpty ? nil : pendingPopups.removeFirst()
		if let popup { recordPopupPresentation(popup) }
	}

	func openPopupAction() {
		let url = popup?.actionURL
		dismissPopup()
		if let url { NSWorkspace.shared.open(url) }
	}

	#if DEBUG
		func resetPopupQueueForDeveloper() {
			pendingPopups.removeAll()
			popup = nil
		}
	#endif

	private func startLauncherUpdateCheck() -> Task<LauncherUpdateCheckOutcome, Never> {
		if isCheckingLauncherUpdates, let launcherUpdateTask {
			return launcherUpdateTask
		}

		isCheckingLauncherUpdates = true
		launcherUpdateStatus = L10n.string(.Launcher.launcherUpdateStatusChecking)
		let task = Task<LauncherUpdateCheckOutcome, Never> { [weak self] in
			guard let self else { return .failed }
			let outcome = await withCheckedContinuation {
				(continuation: CheckedContinuation<LauncherUpdateCheckOutcome, Never>) in
				self.launcherUpdater.checkForUpdateInformation {
					continuation.resume(returning: $0)
				}
			}
			recordLauncherUpdateAvailability(outcome)
			isCheckingLauncherUpdates = false
			return outcome
		}
		launcherUpdateTask = task
		return task
	}

	func recordLauncherUpdateAvailability(_ outcome: LauncherUpdateCheckOutcome) {
		switch outcome {
		case .current:
			launcherUpdateVersion = nil
			launcherUpdateStatus = L10n.string(.Launcher.launcherUpdateStatusUpToDate)
		case .updateAvailable(let version):
			launcherUpdateVersion = version
			launcherUpdateStatus = L10n.string(
				.Launcher.launcherUpdateStatusVersionAvailable(version)
			)
		case .failed:
			launcherUpdateVersion = nil
			launcherUpdateStatus = L10n.string(.Launcher.launcherUpdateStatusFailed)
		}
	}

	private func recordPopupPresentation(_ popup: LauncherPopup) {
		let announcementPrefix = "announcement-"
		if popup.id.hasPrefix(announcementPrefix) {
			preferences.markAnnouncementSeen(String(popup.id.dropFirst(announcementPrefix.count)))
		}
	}
}
