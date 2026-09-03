// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	@discardableResult
	func installRosetta() async -> IntelTranslationState {
		#if DEBUG
			if developerScenario == .onboardingRosetta {
				lifecycle.rosettaInstallationState = .installing
				await Task.yield()
				lifecycle.rosettaInstallationState = .idle
				lifecycle.intelTranslationState = .available
				return .available
			}
		#endif

		return await intelTranslation.installRosetta()
	}
}
