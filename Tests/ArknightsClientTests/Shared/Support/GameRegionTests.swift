// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func gameRegionsMatchTheVerifiedYostarLauncherAPI() {
	#expect(GameRegion.global.gameTag == "Arknights_EN")
	#expect(GameRegion.global.apiBaseURL == URL(string: "https://api-launcher-en.yo-star.com")!)

	#expect(GameRegion.japan.gameTag == "Arknights_JP")
	#expect(GameRegion.japan.apiBaseURL == URL(string: "https://api-launcher-jp.yo-star.com")!)

	#expect(GameRegion.korea.gameTag == "Arknights_KR")
	#expect(GameRegion.korea.apiBaseURL == URL(string: "https://api-launcher-kr.yo-star.com")!)
}

@Test
func globalRegionPreservesThePreExistingPreferencesKey() {
	// installPath.global predates multi-region support; changing it would silently drop
	// existing users' custom install-directory preference on upgrade.
	#expect(GameRegion.global.rawValue == "global")
}

@Test(arguments: [
	(GameRegion.global, "https://account.yo-star.com/contact"),
	(GameRegion.japan, "https://account.yo-star.com/contact"),
	(GameRegion.korea, "https://account.yo-star.com/contact"),
	(GameRegion.china, "https://user.hypergryph.com/support"),
	(GameRegion.chinaBilibili, "https://user.hypergryph.com/support"),
])
func regionsUseTheOfficialPublisherSupportDestination(
	region: GameRegion,
	expectedURL: String
) {
	#expect(SupportLinks.contact(for: region) == URL(string: expectedURL))
}
