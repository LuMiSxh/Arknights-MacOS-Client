// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

@MainActor
struct LauncherPreferencesControllerTests {
	private typealias Key = LauncherPreferencesStore.Key

	@Test
	func resetToDefaultsDoesNotRequestUpdateChecks() {
		let (defaults, suiteName) = makeIsolatedDefaults("LauncherPreferencesControllerTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		store.set(false, for: Key.automaticLauncherUpdates)
		store.set(false, for: Key.automaticGameUpdates)
		store.set(false, for: Key.announcementsEnabled)
		let controller = LauncherPreferencesController(store: store)
		var launcherChecks = 0
		var gameChecks = 0
		var announcementChecks = 0
		var shortcutChanges = 0
		controller.onLauncherUpdateCheckRequested = { launcherChecks += 1 }
		controller.onGameUpdateCheckRequested = { gameChecks += 1 }
		controller.onAnnouncementCheckRequested = { announcementChecks += 1 }
		controller.onScreenshotShortcutChanged = { _ in shortcutChanges += 1 }

		#expect(controller.resetToDefaults(canModifyLaunchOptions: true))

		#expect(launcherChecks == 0)
		#expect(gameChecks == 0)
		#expect(announcementChecks == 0)
		// Resetting still runs the other change handlers, so the hotkey and reminders follow the defaults.
		#expect(shortcutChanges == 1)
		#expect(controller.automaticallyChecksLauncherUpdates)
		#expect(controller.automaticallyChecksGameUpdates)
		#expect(controller.announcementsEnabled)
	}
}
