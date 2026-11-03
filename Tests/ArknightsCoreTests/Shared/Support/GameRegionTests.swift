// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

@Test
func globalRegionPreservesThePreExistingPreferencesKey() {
	// installPath.global predates multi-region support; changing it would silently drop
	// existing users' custom install-directory preference on upgrade.
	#expect(GameRegion.global.rawValue == "global")
}

@MainActor
@Test
func taiwanIsAStableServerThatNeedsNoCanaryFeatures() {
	#expect(RegionAccess(canaryFeaturesEnabled: false).selectableRegions == GameRegion.allCases)

	let (defaults, suiteName) = makeIsolatedDefaults("GameRegionTests")
	defer { defaults.removePersistentDomain(forName: suiteName) }
	let store = LauncherPreferencesStore(defaults: defaults)
	store.setSelectedRegion(.chinaBilibili)
	#expect(store.selectedRegion() == .chinaBilibili)

	store.setSelectedRegion(.taiwan)
	#expect(store.selectedRegion() == .taiwan)
}
