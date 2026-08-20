// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingPanel<Content: View>: View {
	let title: String
	let systemImage: String
	@ViewBuilder let content: Content

	var body: some View {
		SettingsPanel(title: title, systemImage: systemImage) {
			content
		}
	}
}
