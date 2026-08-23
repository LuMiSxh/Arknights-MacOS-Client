// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingGameSettingsView: View {
	@Bindable var model: LauncherViewModel

	var body: some View {
		OnboardingPage(
			title: L10n.string(OnboardingStrings.gameTitle),
			subtitle: L10n.string(OnboardingStrings.gameSubtitle),
			accentColor: model.accentColor
		) {
			SettingsPanel(
				title: L10n.string(OnboardingStrings.displaySettingsPanel), systemImage: "switch.2"
			) {
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.useGameDisplaySettings),
					detail: model.launchOptions.usesGameSettings
						? L10n.string(OnboardingStrings.gameDisplaySettingsDetail)
						: L10n.string(OnboardingStrings.launcherDisplaySettingsDetail),
					isOn: $model.launchOptions.usesGameSettings,
					accentColor: model.accentColor
				)
			}

			SettingsPanel(
				title: L10n.string(OnboardingStrings.windowResolutionPanel),
				systemImage: "rectangle.on.rectangle"
			) {
				AdaptiveSegmentedControl(
					selection: $model.launchOptions.displayMode,
					options: GameDisplayMode.allCases,
					accentColor: model.accentColor
				) { mode in
					Text(shortTitle(for: mode))
				}
				.disabled(model.launchOptions.usesGameSettings)

				SettingsHairline()
				LabeledContent(L10n.string(OnboardingStrings.resolution)) {
					GlassMenuPicker(
						selection: $model.launchOptions.resolution,
						options: GameResolution.allCases.map { ($0, $0.displayName) },
						accentColor: model.accentColor,
						isDisabled: model.launchOptions.usesGameSettings
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
					isOn: $model.launchOptions.usesHighResolutionMode,
					accentColor: model.accentColor
				)
			}
		}
	}

	private func shortTitle(for mode: GameDisplayMode) -> LocalizedStringResource {
		OnboardingStrings.displayMode(mode)
	}
}
