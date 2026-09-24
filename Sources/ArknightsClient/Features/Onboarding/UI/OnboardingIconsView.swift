// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingIconsView: View {
	let customization: CustomizationController
	let browseOperators: () -> Void

	var body: some View {
		OnboardingPage(
			title: OnboardingStrings.iconsTitle,
			subtitle: OnboardingStrings.iconsSubtitle,
			accentColor: customization.accentColor
		) {
			SettingsPanel(
				title: OnboardingStrings.dockIcons, systemImage: "square.grid.2x2"
			) {
				SettingsActionRow(
					title: OnboardingStrings.operatorIcons,
					detail: OnboardingStrings.operatorIconsDetail
				) {
					CapsuleActionButton(
						title: OnboardingStrings.chooseOperator,
						systemImage: "person.2.crop.square.stack",
						tone: .accent(customization.accentColor), presentation: .compact
					) {
						browseOperators()
					}
					CapsuleActionButton(
						title: OnboardingStrings.useDefaults,
						systemImage: "arrow.counterclockwise",
						tone: .neutral,
						presentation: .compact,
						action: customization.resetOperatorIcons
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: OnboardingStrings.customOverrides,
					detail: OnboardingStrings.customOverridesDetail
				) {
					GlassActionMenu(
						title: OnboardingStrings.iconLauncher,
						systemImage: "macwindow",
						accentColor: customization.accentColor
					) {
						Button(
							OnboardingStrings.chooseImage, systemImage: "folder",
							action: customization.chooseCustomAppIcon)
						Button(
							OnboardingStrings.useDefault,
							systemImage: "arrow.counterclockwise",
							action: customization.resetAppIcon)
					}
					GlassActionMenu(
						title: OnboardingStrings.iconGame,
						systemImage: "gamecontroller",
						accentColor: customization.accentColor
					) {
						Button(
							OnboardingStrings.chooseImage, systemImage: "folder",
							action: customization.chooseCustomGameIcon)
						Button(
							OnboardingStrings.useDefault,
							systemImage: "arrow.counterclockwise",
							action: customization.resetGameIcon)
					}
				}
			}
		}
	}
}
