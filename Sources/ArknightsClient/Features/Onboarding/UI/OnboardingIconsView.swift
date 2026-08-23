// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingIconsView: View {
	@Bindable var model: LauncherViewModel
	let browseOperators: () -> Void

	var body: some View {
		OnboardingPage(
			title: L10n.string(OnboardingStrings.iconsTitle),
			subtitle: L10n.string(OnboardingStrings.iconsSubtitle),
			accentColor: model.accentColor
		) {
			SettingsPanel(
				title: L10n.string(OnboardingStrings.dockIcons), systemImage: "square.grid.2x2"
			) {
				SettingsActionRow(
					title: L10n.string(OnboardingStrings.operatorIcons),
					detail: L10n.string(OnboardingStrings.operatorIconsDetail)
				) {
					CapsuleActionButton(
						title: L10n.string(OnboardingStrings.chooseOperator),
						systemImage: "person.2.crop.square.stack",
						tone: .accent(model.accentColor), presentation: .compact
					) {
						browseOperators()
					}
					CapsuleActionButton(
						L10n.string(OnboardingStrings.useDefaults),
						systemImage: "arrow.counterclockwise",
						tone: .neutral,
						presentation: .compact,
						action: model.resetOperatorIcons
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(OnboardingStrings.customOverrides),
					detail: L10n.string(OnboardingStrings.customOverridesDetail)
				) {
					GlassActionMenu(
						title: L10n.string(OnboardingStrings.iconLauncher),
						systemImage: "macwindow",
						accentColor: model.accentColor
					) {
						Button(
							L10n.string(OnboardingStrings.chooseImage), systemImage: "folder",
							action: model.chooseCustomAppIcon)
						Button(
							L10n.string(OnboardingStrings.useDefault),
							systemImage: "arrow.counterclockwise",
							action: model.resetAppIcon)
					}
					GlassActionMenu(
						title: L10n.string(OnboardingStrings.iconGame),
						systemImage: "gamecontroller",
						accentColor: model.accentColor
					) {
						Button(
							L10n.string(OnboardingStrings.chooseImage), systemImage: "folder",
							action: model.chooseCustomGameIcon)
						Button(
							L10n.string(OnboardingStrings.useDefault),
							systemImage: "arrow.counterclockwise",
							action: model.resetGameIcon)
					}
				}
			}
		}
	}
}
