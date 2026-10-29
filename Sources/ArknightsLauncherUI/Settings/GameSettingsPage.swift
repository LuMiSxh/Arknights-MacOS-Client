// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import SwiftUI

struct GameSettingsPage: View {
	package let settings: LauncherPreferencesController
	let gameSession: GameSessionController
	package let lifecycle: LauncherLifecycleStore
	package let accentColor: Color

	var body: some View {
		SettingsPage(
			title: "Game",
			subtitle: "How Arknights looks and plays",
			accentColor: accentColor
		) {
			GameDisplaySettingsPanel(
				settings: settings,
				isLocked: isDisplayLocked,
				accentColor: accentColor,
				metalFXSpatialUpscalingSupported: gameSession.metalFXSpatialUpscalingSupported
			)
			GamePerformanceSettingsPanel(
				settings: settings,
				isLocked: gameSession.isGameActive,
				isFrameRateLocked: isDisplayLocked,
				accentColor: accentColor
			)
			GameCompatibilitySettingsPanel(
				settings: settings,
				isLocked: gameSession.isGameActive,
				accentColor: accentColor
			)
		}
	}

	/// Display settings and the frame rate also wait for storage migration.
	private var isDisplayLocked: Bool {
		gameSession.isGameActive || lifecycle.activity == .maintaining(.migratingStorage)
	}
}
