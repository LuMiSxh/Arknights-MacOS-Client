// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingGameSettingsView: View {
	@Bindable var preferences: LauncherPreferencesController
	let lifecycle: LauncherLifecycleStore
	let accentColor: Color

	var body: some View {
		OnboardingPage(
			title: OnboardingStrings.gameTitle,
			subtitle: OnboardingStrings.gameSubtitle,
			accentColor: accentColor
		) {
			SettingsPanel(
				title: OnboardingStrings.displaySettingsPanel, systemImage: "switch.2"
			) {
				OnboardingToggleRow(
					title: OnboardingStrings.useGameDisplaySettings,
					detail: preferences.launchOptions.usesGameSettings
						? OnboardingStrings.gameDisplaySettingsDetail
						: OnboardingStrings.launcherDisplaySettingsDetail,
					isOn: $preferences.launchOptions.usesGameSettings,
					accentColor: accentColor
				)
			}

			SettingsPanel(
				title: OnboardingStrings.windowResolutionPanel,
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
				LabeledContent(OnboardingStrings.resolution) {
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
				title: OnboardingStrings.pixelDensityPanel,
				systemImage: "sparkles.rectangle.stack"
			) {
				OnboardingToggleRow(
					title: OnboardingStrings.highResolutionTitle,
					detail: OnboardingStrings.highResolutionDetail,
					isOn: $preferences.launchOptions.usesHighResolutionMode,
					accentColor: accentColor
				)
			}

			if preferences.canaryFeaturesEnabled {
				OnboardingCanaryPanel(
					title: OnboardingStrings.runtimeOptimizations,
				) {
					HStack(alignment: .top, spacing: 18) {
						VStack(alignment: .leading, spacing: 3) {
							Text(OnboardingStrings.maximumFrameLatency)
							Text(OnboardingStrings.maximumFrameLatencyDetail)
								.font(.caption)
								.foregroundStyle(.secondary)
								.fixedSize(horizontal: false, vertical: true)
						}
						Spacer(minLength: 18)
						HStack(spacing: 10) {
							SettingsSlider(
								value: frameLatencyBinding,
								range: 1...3,
								step: 1,
								accentColor: LauncherVisuals.warning,
								width: 120
							)
							.accessibilityLabel(
								OnboardingStrings.maximumFrameLatency
							)
							.accessibilityValue(preferences.maximumFrameLatency.formatted())
							Text(preferences.maximumFrameLatency.formatted())
								.monospacedDigit()
								.frame(width: 12)
								.accessibilityHidden(true)
						}
					}
					.disabled(lifecycle.activity.isGameActive)
				}
			}
		}
	}

	private func shortTitle(for mode: GameDisplayMode) -> String {
		OnboardingStrings.displayMode(mode)
	}

	private var frameLatencyBinding: Binding<Double> {
		Binding(
			get: { Double(preferences.maximumFrameLatency) },
			set: { preferences.maximumFrameLatency = Int($0.rounded()) }
		)
	}
}
