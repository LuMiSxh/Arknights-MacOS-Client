// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingGameSettingsView: View {
	@Bindable var preferences: LauncherPreferencesController
	let lifecycle: LauncherLifecycleStore
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
					Text(L10n.string(shortTitle(for: mode)))
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
				Text(L10n.string(OnboardingStrings.higherResolutionDetail))
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

			if preferences.canaryFeaturesEnabled {
				OnboardingCanaryPanel(
					title: L10n.string(OnboardingStrings.runtimeOptimizations),
				) {
					OnboardingToggleRow(
						title: L10n.string(OnboardingStrings.runtimeOptimizations),
						detail: L10n.string(OnboardingStrings.runtimeOptimizationsDetail),
						isOn: $preferences.runtimePerformanceEnabled,
						accentColor: LauncherVisuals.danger
					)
					.disabled(lifecycle.activity.isGameActive)

					SettingsHairline()

					HStack(alignment: .top, spacing: 18) {
						VStack(alignment: .leading, spacing: 3) {
							Text(L10n.string(OnboardingStrings.maximumFrameLatency))
							Text(L10n.string(OnboardingStrings.maximumFrameLatencyDetail))
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
								accentColor: LauncherVisuals.danger,
								width: 120
							)
							.accessibilityLabel(
								L10n.string(OnboardingStrings.maximumFrameLatency)
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

	private func shortTitle(for mode: GameDisplayMode) -> LocalizedStringResource {
		OnboardingStrings.displayMode(mode)
	}

	private var frameLatencyBinding: Binding<Double> {
		Binding(
			get: { Double(preferences.maximumFrameLatency) },
			set: { preferences.maximumFrameLatency = Int($0.rounded()) }
		)
	}
}
