// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Synchronization
import Testing

@testable import ArknightsCore

@MainActor
struct PreferencesMigratorTests {
	@Test
	func pendingStepsRunOnceInOrderAndRecordTheVersion() {
		let (defaults, suiteName) = makeIsolatedDefaults("PreferencesMigratorTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let ran = Mutex<[Int]>([])
		let migrator = PreferencesMigrator(steps: [
			.init(version: 1) { _ in ran.withLock { $0.append(1) } },
			.init(version: 2) { _ in ran.withLock { $0.append(2) } },
			.init(version: 3) { _ in ran.withLock { $0.append(3) } },
		])
		defaults.set(1, forKey: LauncherPreferencesStore.Key.preferencesMigrationVersion)

		migrator.migrate(defaults)
		migrator.migrate(defaults)

		#expect(ran.withLock { $0 } == [2, 3])
		#expect(
			defaults.integer(forKey: LauncherPreferencesStore.Key.preferencesMigrationVersion) == 3)
	}

	@Test
	func legacyThemeAccentsAreRemovedAndCurrentOnesStay() {
		let (defaults, suiteName) = makeIsolatedDefaults("PreferencesMigratorTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(defaults: defaults)
		defaults.set(["hue": 0.1], forKey: "dynamicThemeAccent.legacy-cache")
		store.setDynamicThemeAccent(
			ThemeAccentSnapshot(hue: 0.6, saturation: 0.8, brightness: 0.9), for: "current-cache")

		PreferencesMigrator().migrate(defaults)

		#expect(defaults.object(forKey: "dynamicThemeAccent.legacy-cache") == nil)
		#expect(store.dynamicThemeAccent(for: "current-cache")?.hue == 0.6)
	}
}
