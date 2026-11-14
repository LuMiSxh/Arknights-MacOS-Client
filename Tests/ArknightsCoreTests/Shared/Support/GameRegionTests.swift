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
