// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Highlights Canary settings while keeping the controls inside the panel neutral.
struct OnboardingCanaryPanel<Content: View>: View {
	let title: String
	@ViewBuilder let content: Content

	var body: some View {
		SettingsPanel(title: title, systemImage: "exclamationmark.triangle.fill", tone: .warning) {
			content
		}
	}
}
