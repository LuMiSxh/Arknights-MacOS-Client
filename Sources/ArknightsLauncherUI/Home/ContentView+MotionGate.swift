// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

extension ContentView {
	var isHomeCovered: Bool {
		sheetPresentation.wrappedValue != nil || updateOverlayIsPresented
			|| onboardingIsPresentable
	}

	// Applies to the home layer only; covered state is handled by `isHomeCovered`.
	var homeLayerMotionEnabled: Bool {
		decorativeMotionVisibility.isEnabled && !isHomeCovered
	}

	func gameActivityDidChange(_ isActive: Bool) {
		decorativeMotionVisibility.setGameActive(isActive)
	}
}
