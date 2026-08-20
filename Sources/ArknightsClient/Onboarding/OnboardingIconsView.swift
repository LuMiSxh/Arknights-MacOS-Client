// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingIconsView: View {
	@Bindable var model: LauncherViewModel
	let browseOperators: () -> Void

	var body: some View {
		OnboardingPage(
			title: "Choose your Dock icons",
			subtitle:
				"Choose one operator once. The Launcher and game use distinct, coordinated treatments.",
			accentColor: model.accentColor
		) {
			OnboardingPanel(title: "Dock icons", systemImage: "square.grid.2x2") {
				SettingsActionRow(
					title: "Operator Icons",
					detail: "Creates both Dock icons from the same operator."
				) {
					Button("Choose Operator…", systemImage: "person.2.crop.square.stack") {
						browseOperators()
					}
					Button(
						"Use Defaults",
						systemImage: "arrow.counterclockwise",
						action: model.resetOperatorIcons
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Custom Overrides",
					detail: "Optionally replace either generated icon with a local image."
				) {
					GlassActionMenu(
						title: "Launcher",
						systemImage: "macwindow",
						accentColor: model.accentColor
					) {
						Button(
							"Choose Image…", systemImage: "folder",
							action: model.chooseCustomAppIcon)
						Button(
							"Use Default", systemImage: "arrow.counterclockwise",
							action: model.resetAppIcon)
					}
					GlassActionMenu(
						title: "Game",
						systemImage: "gamecontroller",
						accentColor: model.accentColor
					) {
						Button(
							"Choose Image…", systemImage: "folder",
							action: model.chooseCustomGameIcon)
						Button(
							"Use Default", systemImage: "arrow.counterclockwise",
							action: model.resetGameIcon)
					}
				}
			}
		}
	}
}
