// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import SwiftUI

struct GameSettingsPage: View {
	let settings: LauncherPreferencesController
	let gameSession: GameSessionController
	let lifecycle: LauncherLifecycleStore

	var body: some View {
		SettingsPage(
			title: "Game",
			subtitle: "How Arknights looks and plays"
		) {
			if gameSession.isGameActive, let reason = lifecycle.activity.lockReason {
				SettingsLockBanner(reason: reason)
			}
			GameDisplaySettingsPanel(
				settings: settings,
				isLocked: isDisplayLocked,
				metalFXSpatialUpscalingSupported: gameSession.metalFXSpatialUpscalingSupported
			)
			GamePerformanceSettingsPanel(
				settings: settings,
				isLocked: gameSession.isGameActive,
				isFrameRateLocked: isDisplayLocked,
			)

			GameCompatibilitySettingsPanel(
				settings: settings,
				isLocked: gameSession.isGameActive,
			)
		}
	}

	/// Display settings and the frame rate also wait for storage migration.
	private var isDisplayLocked: Bool {
		gameSession.isGameActive || lifecycle.activity == .maintaining(.migratingStorage)
	}
}
