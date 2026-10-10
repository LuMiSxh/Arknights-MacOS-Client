// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsLauncherUI

@Suite("Primary action ambient effect")
struct PrimaryActionAmbientEffectTests {
	@Test(arguments: LauncherPrimaryActionPresentation.Kind.allCases, [false, true])
	func haloShowsOnlyForAnEnabledPlay(
		kind: LauncherPrimaryActionPresentation.Kind, isDisabled: Bool
	) {
		let expected = kind == .play && !isDisabled
		#expect(
			LauncherPrimaryActionPresentation.showsHalo(kind: kind, isDisabled: isDisabled)
				== expected)
	}
}
