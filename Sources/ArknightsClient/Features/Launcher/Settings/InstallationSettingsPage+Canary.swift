// SPDX-License-Identifier: MPL-2.0

import SwiftUI

extension InstallationSettingsPage {
	@ViewBuilder var canaryRuntimeSettings: some View {
		SettingsHairline()
		SettingsActionRow(
			title: L10n.string(SettingsStrings.followsDefaultAudioOutput),
			detail: L10n.string(SettingsStrings.followsDefaultAudioOutputDetail)
		) {
			SettingsToggle(
				L10n.string(SettingsStrings.followsDefaultAudioOutput),
				isOn: $settings.followsDefaultAudioOutput,
				accentColor: LauncherVisuals.danger
			)
			.disabled(gameSession.isGameActive)
		}
		SettingsHairline()
		SettingsActionRow(
			title: L10n.string(SettingsStrings.frameLatency),
			detail: L10n.string(SettingsStrings.frameLatencyDetail)
		) {
			HStack(spacing: 10) {
				SettingsSlider(
					value: frameLatencyBinding,
					range: 1...3,
					step: 1,
					accentColor: LauncherVisuals.danger,
					width: 120
				)
				.accessibilityLabel(L10n.string(SettingsStrings.frameLatency))
				.accessibilityValue(settings.maximumFrameLatency.formatted())
				Text(settings.maximumFrameLatency.formatted())
					.monospacedDigit()
					.frame(width: 12)
					.accessibilityHidden(true)
			}
			.disabled(gameSession.isGameActive)
		}
	}

	private var frameLatencyBinding: Binding<Double> {
		Binding(
			get: { Double(settings.maximumFrameLatency) },
			set: { settings.maximumFrameLatency = Int($0.rounded()) }
		)
	}
}
