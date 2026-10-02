// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherCommunicationControllerTests {
	@Test
	func announcementsAreRecordedOnlyWhenTheyAreDismissed() {
		let fixture = CommunicationFixture()
		defer { fixture.removeDefaults() }
		let controller = fixture.controller
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

		controller.dismissPopup()
		#expect(controller.popup?.id == "announcement-feedback")
		#expect(!fixture.preferences.seenAnnouncementIDs().contains("feedback"))

		controller.dismissPopup()
		#expect(controller.popup == nil)
		#expect(fixture.preferences.seenAnnouncementIDs().contains("feedback"))
	}

	@Test(arguments: LauncherUpdateButtonScenario.allCases)
	func launcherUpdateButtonTracksAvailabilityAndActiveInstallation(
		scenario: LauncherUpdateButtonScenario
	) {
		let fixture = CommunicationFixture()
		defer { fixture.removeDefaults() }
		let controller = fixture.controller
		var expectedVersion: String?
		var expectedButtonVisibility = true

		switch scenario {
		case .available:
			controller.recordLauncherUpdateAvailability(.updateAvailable("0.5.0"))
			expectedVersion = "0.5.0"
		case .current:
			controller.recordLauncherUpdateAvailability(.updateAvailable("0.5.0"))
			#expect(controller.shouldShowLauncherUpdateButton)
			controller.recordLauncherUpdateAvailability(.current)
			expectedButtonVisibility = false
		case .hiddenInstallation:
			controller.launcherUpdateUserDriver.showInstallingUpdate(
				withApplicationTerminated: true
			) {}
			controller.launcherUpdateUserDriver.dismissFromUser()
		}

		#expect(controller.launcherUpdateVersion == expectedVersion)
		#expect(controller.shouldShowLauncherUpdateButton == expectedButtonVisibility)
		#expect(!controller.launcherUpdateUserDriver.isPresented)
	}
}

enum LauncherUpdateButtonScenario: String, CaseIterable, Sendable {
	case available
	case current
	case hiddenInstallation
}

@MainActor
private struct CommunicationFixture {
	private let suiteName = "LauncherCommunicationControllerTests.\(UUID().uuidString)"
	private let defaults: UserDefaults
	let preferences: LauncherPreferencesStore
	let controller: LauncherCommunicationController

	init() {
		defaults = UserDefaults(suiteName: suiteName)!
		preferences = LauncherPreferencesStore(defaults: defaults)
		let log = LauncherLog(
			fileURL: FileManager.default.temporaryDirectory.appending(path: "\(suiteName).log"))
		controller = LauncherCommunicationController(
			lifecycle: LauncherLifecycleStore(log: log),
			announcementService: LauncherAnnouncementService(),
			preferences: preferences,
			log: log)
	}

	func removeDefaults() {
		defaults.removePersistentDomain(forName: suiteName)
	}
}
