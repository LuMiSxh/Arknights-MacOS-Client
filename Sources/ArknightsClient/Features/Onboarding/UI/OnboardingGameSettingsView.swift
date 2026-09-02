// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingGameSettingsView: View {
	@Bindable var preferences: LauncherPreferencesController
	let accentColor: Color

	var body: some View {
		OnboardingPage(
			title: L10n.string(OnboardingStrings.gameTitle),
			subtitle: L10n.string(OnboardingStrings.gameSubtitle),
			accentColor: accentColor
		) {
			SettingsPanel(
				title: L10n.string(OnboardingStrings.displaySettingsPanel), systemImage: "switch.2"
			) {
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.useGameDisplaySettings),
					detail: preferences.launchOptions.usesGameSettings
						? L10n.string(OnboardingStrings.gameDisplaySettingsDetail)
						: L10n.string(OnboardingStrings.launcherDisplaySettingsDetail),
					isOn: $preferences.launchOptions.usesGameSettings,
					accentColor: accentColor
				)
			}

			SettingsPanel(
				title: L10n.string(OnboardingStrings.windowResolutionPanel),
				systemImage: "rectangle.on.rectangle"
			) {
				AdaptiveSegmentedControl(
					selection: $preferences.launchOptions.displayMode,
					options: GameDisplayMode.allCases,
					accentColor: accentColor
				) { mode in
					Text(shortTitle(for: mode))
				}
				.disabled(preferences.launchOptions.usesGameSettings)

				SettingsHairline()
				LabeledContent(L10n.string(OnboardingStrings.resolution)) {
					GlassMenuPicker(
						selection: $preferences.launchOptions.resolution,
						options: GameResolution.allCases.map { ($0, $0.displayName) },
						accentColor: accentColor,
						isDisabled: preferences.launchOptions.usesGameSettings
					)
				}
				Text(OnboardingStrings.higherResolutionDetail)
					.font(.callout)
					.foregroundStyle(.secondary)
			}

			SettingsPanel(
				title: L10n.string(OnboardingStrings.pixelDensityPanel),
				systemImage: "sparkles.rectangle.stack"
			) {
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.highResolutionTitle),
					detail: L10n.string(OnboardingStrings.highResolutionDetail),
					isOn: $preferences.launchOptions.usesHighResolutionMode,
					accentColor: accentColor
				)
			}
		}
	}

	private func shortTitle(for mode: GameDisplayMode) -> LocalizedStringResource {
		OnboardingStrings.displayMode(mode)
	}
}
