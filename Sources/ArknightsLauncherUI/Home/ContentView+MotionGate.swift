// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

extension ContentView {
	/// True while a sheet, the update overlay, or onboarding hides the home layer.
	var isHomeCovered: Bool {
		sheetPresentation.wrappedValue != nil || updateOverlayIsPresented
			|| onboardingIsPresentable
	}

	/// Window-level gate minus the covered state. Applies to the home layer only.
	var homeLayerMotionEnabled: Bool {
		decorativeMotionVisibility.isEnabled && !isHomeCovered
	}

	func gameActivityDidChange(_ isActive: Bool) {
		decorativeMotionVisibility.setGameActive(isActive)
	}
}
