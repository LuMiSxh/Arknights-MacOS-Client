// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func gameRegionsExposeVerifiedLauncherIdentifiers() {
	#expect(GameRegion.global.gameTag == "Arknights_EN")
	#expect(GameRegion.global.apiBaseURL == URL(string: "https://api-launcher-en.yo-star.com")!)

	#expect(GameRegion.japan.gameTag == "Arknights_JP")
	#expect(GameRegion.japan.apiBaseURL == URL(string: "https://api-launcher-jp.yo-star.com")!)

	#expect(GameRegion.korea.gameTag == "Arknights_KR")
	#expect(GameRegion.korea.apiBaseURL == URL(string: "https://api-launcher-kr.yo-star.com")!)
	#expect(GameRegion.taiwan.gameTag == "Arknights_TC")
}

@Test
func globalRegionPreservesThePreExistingPreferencesKey() {
	// installPath.global predates multi-region support; changing it would silently drop
	// existing users' custom install-directory preference on upgrade.
	#expect(GameRegion.global.rawValue == "global")
}

@Test
func canaryRegionSelectionSeparatesTaiwanAndChinaPermissions() {
	#expect(
		RegionAccess(
			canaryFeaturesEnabled: false,
			chinaClientsEnabled: false,
			taiwanClientEnabled: false
		).selectableRegions
			== GameRegion.yostarCases)
	#expect(
		RegionAccess(
			canaryFeaturesEnabled: true,
			chinaClientsEnabled: false,
			taiwanClientEnabled: false
		).selectableRegions
			== GameRegion.yostarCases)
	#expect(
		RegionAccess(
			canaryFeaturesEnabled: true,
			chinaClientsEnabled: false,
			taiwanClientEnabled: true
		).selectableRegions
			== GameRegion.canaryCases)
	#expect(
		RegionAccess(
			canaryFeaturesEnabled: true,
			chinaClientsEnabled: true,
			taiwanClientEnabled: false
		).selectableRegions
			== [.global, .japan, .korea, .china, .chinaBilibili])
	#expect(
		RegionAccess(
			canaryFeaturesEnabled: false,
			chinaClientsEnabled: true,
			taiwanClientEnabled: true
		).selectableRegions
			== GameRegion.yostarCases)
	#expect(
		RegionAccess(
			canaryFeaturesEnabled: true,
			chinaClientsEnabled: true,
			taiwanClientEnabled: true
		).selectableRegions
			== GameRegion.allCases)
}

@Test(arguments: [
	(
		GameRegion.global, GamePublisher.yostar, GameClientVariant.standard, false, false, false,
		false
	),
	(
		GameRegion.japan, GamePublisher.yostar, GameClientVariant.standard, false, false, false,
		false
	),
	(
		GameRegion.korea, GamePublisher.yostar, GameClientVariant.standard, false, false, false,
		false
	),
	(
		GameRegion.china, GamePublisher.hypergryph, GameClientVariant.standard, true, true, true,
		false
	),
	(
		GameRegion.chinaBilibili, GamePublisher.hypergryph, GameClientVariant.bilibili, true, true,
		true, false
	),
	(
		GameRegion.taiwan, GamePublisher.gryphline, GameClientVariant.standard, true, true, false,
		true
	),
])
func regionsExposeNeutralPublisherAndClientProfile(
	region: GameRegion,
	publisher: GamePublisher,
	variant: GameClientVariant,
	requiresCanaryPermission: Bool,
	requiresACEWarning: Bool,
	requiresChinaClientPermission: Bool,
	requiresTaiwanClientPermission: Bool
) {
	#expect(region.publisher == publisher)
	#expect(region.clientVariant == variant)
	#expect(region.requiresCanaryPermission == requiresCanaryPermission)
	#expect(region.clientProfile.requiresCanaryPermission == requiresCanaryPermission)
	#expect(region.requiresACEWarning == requiresACEWarning)
	#expect(region.requiresChinaClientPermission == requiresChinaClientPermission)
	#expect(region.requiresTaiwanClientPermission == requiresTaiwanClientPermission)
}

@Test
func clientProfilesOwnRuntimePatchEnvironment() {
	#expect(GameRegion.global.runtimeEnvironmentOverrides.isEmpty)
	#expect(
		GameRegion.china.runtimeEnvironmentOverrides
			== ["ARKNIGHTS_RUNTIME_ACE_COMPACT": "1"]
	)
	#expect(
		GameRegion.chinaBilibili.runtimeEnvironmentOverrides
			== [
				"ARKNIGHTS_RUNTIME_ACE_COMPACT": "1",
				"ARKNIGHTS_RUNTIME_CEF_COMPAT": "1",
				"ARKNIGHTS_RUNTIME_CN_COMPAT": "1",
			]
	)
	#expect(
		GameRegion.taiwan.runtimeEnvironmentOverrides
			== ["ARKNIGHTS_RUNTIME_ACE_COMPACT": "1"]
	)
}

@Test(arguments: [
	(GameRegion.global, "https://account.yo-star.com/contact"),
	(GameRegion.japan, "https://account.yo-star.com/contact"),
	(GameRegion.korea, "https://account.yo-star.com/contact"),
	(GameRegion.china, "https://user.hypergryph.com/support"),
	(GameRegion.chinaBilibili, "https://user.hypergryph.com/support"),
	(GameRegion.taiwan, "https://www.gryphline.com/en-us/contacts"),
])
func regionsUseTheOfficialPublisherSupportDestination(
	region: GameRegion,
	expectedURL: String
) {
	#expect(SupportLinks.contact(for: region) == URL(string: expectedURL))
}
