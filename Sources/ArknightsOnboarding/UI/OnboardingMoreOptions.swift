// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

// Holds the secondary questions of a setup step behind one disclosure. It starts collapsed, so
// accepting the defaults never requires opening it.
struct OnboardingMoreOptions<Content: View>: View {
	@State private var isExpanded = false
	@Environment(\.launcherTheme) private var theme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@ViewBuilder let content: Content

	var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.section) {
			Button {
				withAnimation(LauncherMotion.animation(.state, reduceMotion: reduceMotion)) {
					isExpanded.toggle()
				}
			} label: {
				HStack(spacing: LauncherTokens.Spacing.compact) {
					Text("More options")
						.font(LauncherTokens.Typography.sectionLabel)
						.foregroundStyle(theme.textSecondary)
					Image(systemName: "chevron.right")
						.font(.caption.weight(.medium))
						.foregroundStyle(theme.textSecondary)
						.rotationEffect(.degrees(isExpanded ? 90 : 0))
						.accessibilityHidden(true)
					Spacer(minLength: 0)
				}
				.contentShape(.rect)
			}
			.buttonStyle(.plain)
			.keyboardFocusIndicator(
				in: RoundedRectangle(cornerRadius: LauncherTokens.Radius.control)
			)
			.padding(.horizontal, LauncherTokens.Spacing.panel)
			.accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

			if isExpanded {
				content
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}
