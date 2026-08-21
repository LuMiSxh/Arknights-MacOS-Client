// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingIconsView: View {
	@Bindable var model: LauncherViewModel
	let browseOperators: () -> Void

	var body: some View {
		OnboardingPage(
			title: "Choose your Dock icons",
			subtitle:
				"Choose an operator to create a Launcher icon with that character and a Game icon in the original Arknights style.",
			accentColor: model.accentColor
		) {
			OnboardingPanel(title: "Dock icons", systemImage: "square.grid.2x2") {
				SettingsActionRow(
					title: "Operator Icons",
					detail: "The same character is used for both Dock icons."
				) {
					CapsuleActionButton(
						title: "Choose Operator…", systemImage: "person.2.crop.square.stack",
						tone: .accent(model.accentColor), presentation: .compact
					) {
						browseOperators()
					}
					CapsuleActionButton(
						"Use Defaults",
						systemImage: "arrow.counterclockwise",
						tone: .neutral,
						presentation: .compact,
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
