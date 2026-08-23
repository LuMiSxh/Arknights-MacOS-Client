// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherCommunicationControllerTests {
	@Test
	func queuedPopupsAreRecordedOnlyWhenTheyBecomeVisible() {
		let suiteName = "LauncherCommunicationControllerTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferences = LauncherPreferencesStore(defaults: defaults)
		let logURL = FileManager.default.temporaryDirectory.appending(
			path: "\(suiteName).log"
		)
		let controller = LauncherCommunicationController(
			updateChecker: LauncherUpdateChecker(),
			announcementService: LauncherAnnouncementService(),
			preferences: preferences,
			log: LauncherLog(fileURL: logURL)
		)
		let popup: (String) -> LauncherPopup = { id in
			LauncherPopup(
				id: id,
				title: "Test",
				content: .markdown("Test"),
				dismissTitle: "Done",
				actionTitle: nil,
				actionURL: nil
			)
		}

		controller.enqueuePopup(popup("official-notice"))
		controller.enqueuePopup(popup("announcement-feedback"))
		controller.enqueuePopup(popup("launcher-update-0.2.0"))

		#expect(!preferences.seenAnnouncementIDs().contains("feedback"))
		#expect(preferences.presentedLauncherUpdate() == nil)

		controller.dismissPopup()
		#expect(preferences.seenAnnouncementIDs().contains("feedback"))
		#expect(preferences.presentedLauncherUpdate() == nil)

		controller.dismissPopup()
		#expect(preferences.presentedLauncherUpdate() == "0.2.0")
	}
}
