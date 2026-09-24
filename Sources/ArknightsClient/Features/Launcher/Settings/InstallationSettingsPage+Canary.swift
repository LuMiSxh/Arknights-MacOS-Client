// SPDX-License-Identifier: MPL-2.0

import SwiftUI

extension InstallationSettingsPage {
	@ViewBuilder var canaryRuntimeSettings: some View {
		SettingsActionRow(
			title: SettingsStrings.chinaClients,
			detail: SettingsStrings.chinaClientsDetail
		) {
			SettingsToggle(
				SettingsStrings.chinaClients,
				isOn: $settings.chinaClientsEnabled,
				accentColor: LauncherVisuals.warning
			)
		}
		.disabled(lifecycle.activity != .idle)
		SettingsHairline()
		SettingsActionRow(
			title: SettingsStrings.taiwanClient,
			detail: SettingsStrings.taiwanClientDetail
		) {
			SettingsToggle(
				SettingsStrings.taiwanClient,
				isOn: $settings.taiwanClientEnabled,
				accentColor: LauncherVisuals.warning
			)
		}
		.disabled(lifecycle.activity != .idle)
		SettingsHairline()
		SettingsActionRow(
			title: SettingsStrings.frameLatency,
			detail: SettingsStrings.frameLatencyDetail
		) {
			HStack(spacing: 10) {
				SettingsSlider(
					value: frameLatencyBinding,
					range: 1...3,
					step: 1,
					accentColor: LauncherVisuals.warning,
					width: 120
				)
				.accessibilityLabel(SettingsStrings.frameLatency)
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
