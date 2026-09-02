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
		let log = LauncherLog(fileURL: logURL)
		let lifecycle = LauncherLifecycleStore(log: log)
		let controller = LauncherCommunicationController(
			lifecycle: lifecycle,
			announcementService: LauncherAnnouncementService(),
			preferences: preferences,
			log: log
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

		#expect(!preferences.seenAnnouncementIDs().contains("feedback"))

		controller.dismissPopup()
		#expect(preferences.seenAnnouncementIDs().contains("feedback"))

		controller.dismissPopup()
		#expect(controller.popup == nil)
	}

	@Test
	func silentProbeUpdatesAvailabilityWithoutPresentingTheDriver() {
		let suiteName = "LauncherCommunicationControllerTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferences = LauncherPreferencesStore(defaults: defaults)
		let logURL = FileManager.default.temporaryDirectory.appending(
			path: "\(suiteName).log"
		)
		let log = LauncherLog(fileURL: logURL)
		let lifecycle = LauncherLifecycleStore(log: log)
		let controller = LauncherCommunicationController(
			lifecycle: lifecycle,
			announcementService: LauncherAnnouncementService(),
			preferences: preferences,
			log: log
		)
		controller.recordLauncherUpdateAvailability(.updateAvailable("0.5.0"))

		#expect(controller.launcherUpdateVersion == "0.5.0")
		#expect(!controller.launcherUpdateUserDriver.isPresented)
	}

	@Test
	func currentAvailabilityClearsTheLauncherUpdateAction() {
		let suiteName = "LauncherCommunicationControllerTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferences = LauncherPreferencesStore(defaults: defaults)
		let logURL = FileManager.default.temporaryDirectory.appending(path: "\(suiteName).log")
		let log = LauncherLog(fileURL: logURL)
		let lifecycle = LauncherLifecycleStore(log: log)
		let controller = LauncherCommunicationController(
			lifecycle: lifecycle,
			announcementService: LauncherAnnouncementService(),
			preferences: preferences,
			log: log
		)
		controller.recordLauncherUpdateAvailability(.updateAvailable("0.5.0"))
		#expect(controller.shouldShowLauncherUpdateButton)

		controller.recordLauncherUpdateAvailability(.current)

		#expect(controller.launcherUpdateVersion == nil)
		#expect(!controller.shouldShowLauncherUpdateButton)
	}

	@Test
	func hiddenActiveUpdateKeepsLauncherButtonVisibleWithoutCachedVersion() {
		let suiteName = "LauncherCommunicationControllerTests.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let preferences = LauncherPreferencesStore(defaults: defaults)
		let logURL = FileManager.default.temporaryDirectory.appending(path: "\(suiteName).log")
		let log = LauncherLog(fileURL: logURL)
		let lifecycle = LauncherLifecycleStore(log: log)
		let controller = LauncherCommunicationController(
			lifecycle: lifecycle,
			announcementService: LauncherAnnouncementService(),
			preferences: preferences,
			log: log
		)
		controller.launcherUpdateUserDriver.showReady { _ in }
		controller.launcherUpdateUserDriver.dismissFromUser()

		#expect(controller.launcherUpdateVersion == nil)
		#expect(!controller.launcherUpdateUserDriver.isPresented)
		#expect(controller.shouldShowLauncherUpdateButton)
	}
}
