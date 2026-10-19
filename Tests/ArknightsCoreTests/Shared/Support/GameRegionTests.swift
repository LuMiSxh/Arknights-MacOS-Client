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
func onlyTaiwanSelectionDependsOnCanaryPermissions() {
	for (canary, taiwan) in [(false, false), (true, false), (false, true)] {
		#expect(
			RegionAccess(canaryFeaturesEnabled: canary, taiwanClientEnabled: taiwan)
				.selectableRegions == GameRegion.generallyAvailableCases)
	}
	#expect(
		RegionAccess(canaryFeaturesEnabled: true, taiwanClientEnabled: true).selectableRegions
			== GameRegion.allCases)

	let (defaults, suiteName) = makeIsolatedDefaults("GameRegionTests")
	defer { defaults.removePersistentDomain(forName: suiteName) }
	let store = LauncherPreferencesStore(defaults: defaults)
	typealias Key = LauncherPreferencesStore.Key

	store.setSelectedRegion(.chinaBilibili)
	#expect(store.selectedRegion() == .chinaBilibili)

	store.setSelectedRegion(.taiwan)
	#expect(store.selectedRegion() == .global)
	store.set(true, for: Key.canaryFeaturesEnabled)
	#expect(store.selectedRegion() == .global)
	store.set(true, for: Key.taiwanClientEnabled)
	#expect(store.selectedRegion() == .taiwan)
	store.set(false, for: Key.taiwanClientEnabled)
	#expect(store.selectedRegion() == .global)
}
