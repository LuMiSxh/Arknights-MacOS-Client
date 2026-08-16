// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

extension LauncherViewModel {
	func checkAnnouncements() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.announcement)
				return
			}
		#endif
		guard announcementsEnabled else { return }
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
							now: Date(),
							seenIDs: seenIDs
						)
					})
				else { return }
				enqueuePopup(
					LauncherPopup(
						id: "announcement-\(announcement.id)",
						title: announcement.title,
						content: .markdown(announcement.body),
						dismissTitle: "Done",
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

	func presentLauncherUpdateIfNeeded(_ release: LauncherRelease) {
		guard preferences.presentedLauncherUpdate() != release.version else { return }
		let notes = release.body?.trimmingCharacters(in: .whitespacesAndNewlines)
		let content =
			notes.flatMap { $0.isEmpty ? nil : $0 } ?? "A new launcher version is available."
		enqueuePopup(
			LauncherPopup(
				id: "launcher-update-\(release.version)",
				title: "Arknights Client \(release.version)",
				content: .markdown(content),
				dismissTitle: "Later",
				actionTitle: "View Release",
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
