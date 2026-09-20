// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Adds the plain-language consequence that Settings tooltips cannot teach during setup.
struct OnboardingToggleRow: View {
	let title: String
	let detail: String
	@Binding var isOn: Bool
	let accentColor: Color

	var body: some View {
		SettingsActionRow(title: title, detail: detail) {
			SettingsToggle(title, isOn: $isOn, accentColor: accentColor)
		}
	}
}
