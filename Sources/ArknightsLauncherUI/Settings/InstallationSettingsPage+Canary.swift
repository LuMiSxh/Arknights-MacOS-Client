// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

extension InstallationSettingsPage {
	@ViewBuilder var canaryRuntimeSettings: some View {
		SettingsActionRow(
			title: "Allow Taiwan region",
			detail: "Adds the Taiwan region to the region list."
		) {
			SettingsToggle(
				"Allow Taiwan region",
				isOn: $settings.taiwanClientEnabled,
				accentColor: LauncherVisuals.warning
			)
		}
		.disabled(lifecycle.activity != .idle)
	}
}
