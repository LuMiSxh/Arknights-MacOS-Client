// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingIconsView: View {
	@Bindable var model: LauncherViewModel
	let browseLauncherOperators: () -> Void
	let browseGameOperators: () -> Void

	var body: some View {
		OnboardingPage(
			title: "Choose your Dock icons",
			subtitle:
				"Set either Dock icon independently. Operator presets use the correct treatment for the icon you choose.",
			accentColor: model.accentColor
		) {
			OnboardingPanel(title: "Dock icons", systemImage: "square.grid.2x2") {
				SettingsActionRow(
					title: "Launcher Icon",
					detail: "Choose an operator in the Launcher treatment, or use a local image."
				) {
					Button("Operators…", systemImage: "person.crop.square") {
						browseLauncherOperators()
					}
					Button("Choose…", systemImage: "folder", action: model.chooseCustomAppIcon)
					Button(
						"Use Default",
						systemImage: "arrow.counterclockwise",
						action: model.resetAppIcon
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Game Icon",
					detail: "Choose an operator in the Game treatment, or use a local image."
				) {
					Button("Operators…", systemImage: "person.crop.square") {
						browseGameOperators()
					}
					Button("Choose…", systemImage: "folder", action: model.chooseCustomGameIcon)
					Button(
						"Use Default",
						systemImage: "arrow.counterclockwise",
						action: model.resetGameIcon
					)
				}
			}
		}
	}
}
