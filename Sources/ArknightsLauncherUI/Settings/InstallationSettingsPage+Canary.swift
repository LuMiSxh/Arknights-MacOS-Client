// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

extension InstallationSettingsPage {
	@ViewBuilder var canaryRuntimeSettings: some View {
		SettingsActionRow(
			title: "Allow Taiwan server",
			detail: "Adds the Taiwan server to the server list."
		) {
			SettingsToggle(
				"Allow Taiwan server",
				isOn: $settings.taiwanClientEnabled,
				accentColor: LauncherVisuals.warning
			)
		}
		.disabled(lifecycle.activity != .idle)
	}
}
