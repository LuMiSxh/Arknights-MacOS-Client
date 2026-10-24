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
				isLocked: gameSession.isGameActive
					|| lifecycle.activity == .maintaining(.migratingStorage),
				accentColor: accentColor,
				metalFXSpatialUpscalingSupported: gameSession.metalFXSpatialUpscalingSupported
			)
			GameAdvancedSettingsPanel(
				settings: settings,
				isLocked: gameSession.isGameActive,
				accentColor: accentColor
			)
		}
	}
}
