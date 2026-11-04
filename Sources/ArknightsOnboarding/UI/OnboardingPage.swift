// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

// Gives every setup step the same title rule and content rhythm as a launcher Settings page.
struct OnboardingPage<Content: View>: View {
	let title: String
	let subtitle: String
	@ViewBuilder let content: Content
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.section) {
			SectionPageHeader(
				title: title,
				subtitle: subtitle,
				fixesSubtitleHeight: true
			)
			content
		}
		.padding(LauncherTokens.Spacing.panel)
		.background {
			RoundedRectangle(cornerRadius: LauncherTokens.Radius.panel)
				// Same opacity as the Settings sheet, so panel text stays readable over the artwork.
				.fill(theme.sheetTint)
		}
	}
}
