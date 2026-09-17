// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	static func shouldPresentACEWarning(for region: GameRegion, acknowledged: Bool) -> Bool {
		region.requiresACEWarning && !acknowledged
	}

	func launch() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.launching)
				return
			}
		#endif
		let region = installation.region
		if Self.shouldPresentACEWarning(
			for: region,
			acknowledged: preferences.hasAcknowledgedACEWarning(for: region)
		) {
			pendingACEWarningRegion = region
			return
		}
		gameSession.launch()
	}

	func confirmACEWarningAndLaunch() {
		guard let region = pendingACEWarningRegion else { return }
		guard installation.region == region, region.requiresACEWarning else {
			pendingACEWarningRegion = nil
			return
		}
		preferences.markACEWarningAcknowledged(for: region)
		pendingACEWarningRegion = nil
		gameSession.launch()
	}

	func cancelACEWarning() {
		pendingACEWarningRegion = nil
	}

	func stopGame() {
		#if DEBUG
			if isDeveloperMode {
				applyDeveloperScenario(.ready)
				return
			}
		#endif
		gameSession.stopGame()
	}

	func stopGameForApplicationTermination() {
		#if DEBUG
			if isDeveloperMode { return }
		#endif
		gameSession.stopGameForApplicationTermination()
	}
}
