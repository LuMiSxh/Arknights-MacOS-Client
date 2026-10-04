// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct GameSettingsPage: View {
	let settings: LauncherPreferencesController
	let gameSession: GameSessionController
	let lifecycle: LauncherLifecycleStore
	let accentColor: Color

	var body: some View {
		SettingsPage(
			title: SettingsStrings.gameTitle,
			subtitle: SettingsStrings.gameSubtitle,
			accentColor: accentColor
		) {
			GameDisplaySettingsPanel(
				settings: settings,
				isLocked: gameSession.isGameActive
					|| lifecycle.activity == .maintaining(.migratingStorage),
				accentColor: accentColor
			)
			GameAdvancedSettingsPanel(
				settings: settings,
				isLocked: gameSession.isGameActive,
				accentColor: accentColor
			)
		}
	}
}
