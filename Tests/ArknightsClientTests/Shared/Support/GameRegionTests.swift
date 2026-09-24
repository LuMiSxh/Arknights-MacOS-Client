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
		GameRegion.selectableCases(
			canaryEnabled: false,
			chinaClientsEnabled: false,
			taiwanClientEnabled: false
		)
			== GameRegion.yostarCases)
	#expect(
		GameRegion.selectableCases(
			canaryEnabled: true,
			chinaClientsEnabled: false,
			taiwanClientEnabled: false
		)
			== GameRegion.yostarCases)
	#expect(
		GameRegion.selectableCases(
			canaryEnabled: true,
			chinaClientsEnabled: false,
			taiwanClientEnabled: true
		)
			== GameRegion.canaryCases)
	#expect(
		GameRegion.selectableCases(
			canaryEnabled: true,
			chinaClientsEnabled: true,
			taiwanClientEnabled: false
		)
			== [.global, .japan, .korea, .china, .chinaBilibili])
	#expect(
		GameRegion.selectableCases(
			canaryEnabled: false,
			chinaClientsEnabled: true,
			taiwanClientEnabled: true
		)
			== GameRegion.yostarCases)
	#expect(
		GameRegion.selectableCases(
			canaryEnabled: true,
			chinaClientsEnabled: true,
			taiwanClientEnabled: true
		)
			== GameRegion.allCases)
}

@Test
func aceProtectedClientsAreMarkedForWarning() {
	#expect(GameRegion.china.requiresACEWarning)
	#expect(GameRegion.chinaBilibili.requiresACEWarning)
	#expect(GameRegion.taiwan.requiresACEWarning)
	#expect(GameRegion.china.requiresChinaClientPermission)
	#expect(GameRegion.chinaBilibili.requiresChinaClientPermission)
	#expect(!GameRegion.taiwan.requiresChinaClientPermission)
	#expect(GameRegion.taiwan.requiresTaiwanClientPermission)
	#expect(!GameRegion.china.requiresTaiwanClientPermission)
	#expect(!GameRegion.global.requiresACEWarning)
	#expect(!GameRegion.japan.requiresACEWarning)
}

@Test(arguments: [
	(GameRegion.global, GamePublisher.yostar, GameClientVariant.standard, false, false),
	(GameRegion.japan, GamePublisher.yostar, GameClientVariant.standard, false, false),
	(GameRegion.korea, GamePublisher.yostar, GameClientVariant.standard, false, false),
	(GameRegion.china, GamePublisher.hypergryph, GameClientVariant.standard, true, true),
	(GameRegion.chinaBilibili, GamePublisher.hypergryph, GameClientVariant.bilibili, true, true),
	(GameRegion.taiwan, GamePublisher.gryphline, GameClientVariant.standard, true, true),
])
func regionsExposeNeutralPublisherAndClientProfile(
	region: GameRegion,
	publisher: GamePublisher,
	variant: GameClientVariant,
	requiresCanaryPermission: Bool,
	requiresACEWarning: Bool
) {
	#expect(region.publisher == publisher)
	#expect(region.clientVariant == variant)
	#expect(region.requiresCanaryPermission == requiresCanaryPermission)
	#expect(region.clientProfile.requiresCanaryPermission == requiresCanaryPermission)
	#expect(region.requiresACEWarning == requiresACEWarning)
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
