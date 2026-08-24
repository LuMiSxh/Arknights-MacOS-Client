// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	var isDeveloperMode: Bool {
		#if DEBUG
			developerScenario != nil
		#else
			false
		#endif
	}

	var isOnboardingPreview: Bool {
		#if DEBUG
			developerScenario == .onboardingRosetta
		#else
			false
		#endif
	}
}
