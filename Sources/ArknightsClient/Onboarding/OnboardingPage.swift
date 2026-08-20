// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Gives every setup step the same title rule and content rhythm as a launcher Settings page.
struct OnboardingPage<Content: View>: View {
	let title: String
	let subtitle: String
	let accentColor: Color
	@ViewBuilder let content: Content

	var body: some View {
		VStack(alignment: .leading, spacing: 18) {
			VStack(alignment: .leading, spacing: 7) {
				Text(title)
					.font(.largeTitle.bold())
				Text(subtitle)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
				HStack(spacing: 8) {
					Rectangle()
						.fill(accentColor)
						.frame(width: 72, height: 3)
					Rectangle()
						.fill(.secondary.opacity(0.28))
						.frame(height: 1)
						.frame(maxWidth: .infinity)
				}
				.padding(.top, 5)
			}

			content
		}
	}
}
