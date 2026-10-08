// SPDX-License-Identifier: MPL-2.0

import SwiftUI

extension InstallationSettingsPage {
	@ViewBuilder var canaryRuntimeSettings: some View {
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
	}
}
