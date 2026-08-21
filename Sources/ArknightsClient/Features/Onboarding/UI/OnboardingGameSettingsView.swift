// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingGameSettingsView: View {
	@Bindable var model: LauncherViewModel

	var body: some View {
		OnboardingPage(
			title: "Tune the game window",
			subtitle:
				"These choices affect the next launch. Start conservatively on base-model Macs; you can raise resolution after confirming smooth gameplay.",
			accentColor: model.accentColor
		) {
			OnboardingPanel(title: "Who controls display settings?", systemImage: "switch.2") {
				OnboardingToggleRow(
					title: "Use In-Game Display Settings",
					detail: model.launchOptions.usesGameSettings
						? "Changes made inside Arknights remain in control after the first successful launch."
						: "The launcher overrides window mode and resolution every time the game starts.",
					isOn: $model.launchOptions.usesGameSettings,
					accentColor: model.accentColor
				)
			}

			OnboardingPanel(title: "Window & resolution", systemImage: "rectangle.on.rectangle") {
				AdaptiveSegmentedControl(
					selection: $model.launchOptions.displayMode,
					options: GameDisplayMode.allCases,
					accentColor: model.accentColor
				) { mode in
					Text(shortTitle(for: mode))
				}
				.disabled(model.launchOptions.usesGameSettings)

				SettingsHairline()
				LabeledContent("Resolution") {
					GlassMenuPicker(
						selection: $model.launchOptions.resolution,
						options: GameResolution.allCases.map { ($0, $0.displayName) },
						accentColor: model.accentColor,
						isDisabled: model.launchOptions.usesGameSettings
					)
				}
				Text(
					"Higher resolutions increase the work done by both Wine and the graphics translator."
				)
				.font(.callout)
				.foregroundStyle(.secondary)
			}

			OnboardingPanel(title: "Pixel density", systemImage: "sparkles.rectangle.stack") {
				OnboardingToggleRow(
					title: "High-Resolution Mode",
					detail:
						"Makes text sharper on Retina displays, but the larger backing surface can reduce performance. Turn it off first when the game feels uneven.",
					isOn: $model.launchOptions.usesHighResolutionMode,
					accentColor: model.accentColor
				)
			}
		}
	}

	private func shortTitle(for mode: GameDisplayMode) -> String {
		switch mode {
		case .fullscreen: "Fullscreen"
		case .windowed: "Windowed"
		case .borderlessWindow: "Borderless"
		}
	}
}
