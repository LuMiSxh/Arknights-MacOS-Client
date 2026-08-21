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
			SectionPageHeader(
				title: title,
				subtitle: subtitle,
				accentColor: accentColor,
				fixesSubtitleHeight: true
			)
			content
		}
	}
}
