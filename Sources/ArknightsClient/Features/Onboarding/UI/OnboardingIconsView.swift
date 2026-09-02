// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingIconsView: View {
	let customization: CustomizationController
	let browseOperators: () -> Void

	var body: some View {
		OnboardingPage(
			title: L10n.string(OnboardingStrings.iconsTitle),
			subtitle: L10n.string(OnboardingStrings.iconsSubtitle),
			accentColor: customization.accentColor
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
						tone: .accent(customization.accentColor), presentation: .compact
					) {
						browseOperators()
					}
					CapsuleActionButton(
						title: L10n.string(OnboardingStrings.useDefaults),
						systemImage: "arrow.counterclockwise",
						tone: .neutral,
						presentation: .compact,
						action: customization.resetOperatorIcons
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
						accentColor: customization.accentColor
					) {
						Button(
							L10n.string(OnboardingStrings.chooseImage), systemImage: "folder",
							action: customization.chooseCustomAppIcon)
						Button(
							L10n.string(OnboardingStrings.useDefault),
							systemImage: "arrow.counterclockwise",
							action: customization.resetAppIcon)
					}
					GlassActionMenu(
						title: L10n.string(OnboardingStrings.iconGame),
						systemImage: "gamecontroller",
						accentColor: customization.accentColor
					) {
						Button(
							L10n.string(OnboardingStrings.chooseImage), systemImage: "folder",
							action: customization.chooseCustomGameIcon)
						Button(
							L10n.string(OnboardingStrings.useDefault),
							systemImage: "arrow.counterclockwise",
							action: customization.resetGameIcon)
					}
				}
			}
		}
	}
}
