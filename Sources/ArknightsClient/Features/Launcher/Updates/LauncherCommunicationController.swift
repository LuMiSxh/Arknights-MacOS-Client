// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Observation

/// Owns launcher updates, announcements, Yostar notices, and their shared popup queue.
@MainActor
@Observable
final class LauncherCommunicationController {
	var launcherUpdate: LauncherRelease?
	var launcherUpdateStatus: String?
	var isCheckingLauncherUpdates = false
	var popup: LauncherPopup?

	private let updateChecker: LauncherUpdateChecker
	private let announcementService: LauncherAnnouncementService
	private let preferences: LauncherPreferencesStore
	private let log: LauncherLog
	private var pendingPopups: [LauncherPopup] = []
	private var presentedNoticeContent: String?
	@ObservationIgnored private var launcherUpdateTask: Task<LauncherUpdateCheckOutcome, Never>?
	@ObservationIgnored private var announcementTask: Task<Void, Never>?

	init(
		updateChecker: LauncherUpdateChecker,
		announcementService: LauncherAnnouncementService,
		preferences: LauncherPreferencesStore,
		log: LauncherLog
	) {
		self.updateChecker = updateChecker
		self.announcementService = announcementService
		self.preferences = preferences
		self.log = log
	}

	deinit {
		launcherUpdateTask?.cancel()
		announcementTask?.cancel()
	}

	func checkLauncherUpdates() {
		_ = startLauncherUpdateCheck()
	}

	/// Reuses an active request so onboarding and the automatic check cannot race.
	func launcherUpdateCheckForOnboarding() async -> LauncherUpdateCheckOutcome {
		await startLauncherUpdateCheck().value
	}

	func openLauncherUpdate() {
		guard let url = launcherUpdate?.htmlURL else { return }
		NSWorkspace.shared.open(url)
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

	func presentLauncherUpdateIfNeeded(_ release: LauncherRelease) {
		guard preferences.presentedLauncherUpdate() != release.version else { return }
		let notes = release.body?.trimmingCharacters(in: .whitespacesAndNewlines)
		let content =
			notes.flatMap { $0.isEmpty ? nil : $0 }
			?? L10n.string(LauncherStrings.popupReleaseFallback)
		enqueuePopup(
			LauncherPopup(
				id: "launcher-update-\(release.version)",
				title: L10n.string(LauncherStrings.popupUpdateTitle(release.version)),
				content: .markdown(content),
				dismissTitle: L10n.string(LauncherStrings.popupLater),
				actionTitle: L10n.string(LauncherStrings.popupViewRelease),
				actionURL: release.htmlURL
			)
		)
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

		launcherUpdateTask?.cancel()
		isCheckingLauncherUpdates = true
		launcherUpdateStatus = L10n.string(.Launcher.launcherUpdateStatusChecking)
		let task = Task { [weak self] in
			guard let self else { return LauncherUpdateCheckOutcome.failed }
			defer { isCheckingLauncherUpdates = false }
			guard
				let endpointString = Bundle.main.object(
					forInfoDictionaryKey: "LauncherUpdatesURL"
				) as? String,
				let endpoint = URL(string: endpointString)
			else {
				launcherUpdate = nil
				launcherUpdateStatus = L10n.string(
					.Launcher.launcherUpdateStatusSourceUnavailable)
				await log.error("Launcher update check failed: update source unavailable")
				return .unavailable
			}

			do {
				guard let release = try await updateChecker.latestRelease(from: endpoint) else {
					launcherUpdate = nil
					launcherUpdateStatus = L10n.string(
						.Launcher.launcherUpdateStatusNoReleases)
					await log.info("Launcher update check completed; no releases available")
					return .current
				}
				let currentVersion = Bundle.main.shortVersionString ?? "0"
				if !release.isDraft && !release.isPrerelease
					&& updateChecker.isNewer(release.version, than: currentVersion)
				{
					launcherUpdate = release
					launcherUpdateStatus = L10n.string(
						.Launcher.launcherUpdateStatusVersionAvailable(release.version)
					)
					presentLauncherUpdateIfNeeded(release)
					await log.info(
						"Launcher update check completed; status=Version \(release.version) available"
					)
					return .updateAvailable(release)
				}

				launcherUpdate = nil
				launcherUpdateStatus = L10n.string(.Launcher.launcherUpdateStatusUpToDate)
				await log.info("Launcher update check completed; status=Up to date")
				return .current
			} catch is CancellationError {
				launcherUpdateStatus = nil
				return .failed
			} catch {
				launcherUpdate = nil
				launcherUpdateStatus = L10n.string(.Launcher.launcherUpdateStatusFailed)
				await log.error("Launcher update check failed: \(error.localizedDescription)")
				return .failed
			}
		}
		launcherUpdateTask = task
		return task
	}

	private func recordPopupPresentation(_ popup: LauncherPopup) {
		let announcementPrefix = "announcement-"
		let launcherUpdatePrefix = "launcher-update-"
		if popup.id.hasPrefix(announcementPrefix) {
			preferences.markAnnouncementSeen(String(popup.id.dropFirst(announcementPrefix.count)))
		} else if popup.id.hasPrefix(launcherUpdatePrefix) {
			preferences.markLauncherUpdatePresented(
				String(popup.id.dropFirst(launcherUpdatePrefix.count))
			)
		}
	}
}
