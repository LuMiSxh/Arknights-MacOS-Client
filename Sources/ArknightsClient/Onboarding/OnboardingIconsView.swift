// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingIconsView: View {
	@Bindable var model: LauncherViewModel
	let browseLauncherIcons: () -> Void
	let browseGameIcons: () -> Void

	var body: some View {
		OnboardingPage(
			title: "Choose the two Dock icons",
			subtitle:
				"The launcher and the running game are separate macOS processes, so each has its own icon. Each preset gallery lets you choose an operator and icon treatment before applying it.",
			accentColor: model.accentColor
		) {
			OnboardingPanel(title: "Dock icons", systemImage: "square.grid.2x2") {
				SettingsActionRow(
					title: "Launcher Icon",
					detail: "Dock and Finder icon for this launcher."
				) {
					Button("Presets…", action: browseLauncherIcons)
					Button("Choose…", action: model.chooseCustomAppIcon)
					Button("Use Default", action: model.resetAppIcon)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Game Icon",
					detail: "Dock icon used by Arknights on its next launch."
				) {
					Button("Presets…", action: browseGameIcons)
					Button("Choose…", action: model.chooseCustomGameIcon)
					Button("Use Default", action: model.resetGameIcon)
				}
			}
		}
	}
}
