// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Highlights Canary settings while keeping the controls inside the panel neutral.
struct OnboardingCanaryPanel<Content: View>: View {
	let title: String
	@ViewBuilder let content: Content

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Label(title, systemImage: "exclamationmark.triangle.fill")
				.font(.headline)
				.foregroundStyle(LauncherVisuals.danger)
				.symbolRenderingMode(.hierarchical)
			content
		}
		.padding(18)
		.frame(maxWidth: .infinity, alignment: .leading)
		.adaptiveGlassEffect(in: .rect(cornerRadius: 18))
		.overlay {
			RoundedRectangle(cornerRadius: 18)
				.strokeBorder(LauncherVisuals.danger.opacity(0.45), lineWidth: 1)
		}
	}
}
