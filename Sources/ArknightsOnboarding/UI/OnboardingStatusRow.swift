// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

// One check or summary line inside a setup panel. The panel supplies the row padding and dividers.
struct OnboardingStatusRow<Content: View>: View {
	let title: String
	var detail: String?
	// A nil image shows a spinner while a check runs.
	var systemImage: String?
	var tone: SettingsPanelTone = .neutral
	@ViewBuilder let content: Content
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		HStack(alignment: .top, spacing: LauncherVisuals.Spacing.control) {
			icon
				.frame(width: 20, height: 20)
			VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.control) {
				VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.compact) {
					Text(title)
						.fontWeight(.medium)
					if let detail {
						Text(detail)
							.font(.callout)
							.foregroundStyle(theme.textSecondary)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
				content
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	@ViewBuilder
	private var icon: some View {
		if let systemImage {
			Image(systemName: systemImage)
				.foregroundStyle(iconColor)
				.accessibilityHidden(true)
		} else {
			ProgressView()
		}
	}

	private var iconColor: Color {
		switch tone {
		case .neutral: theme.textSecondary
		case .success: theme.successInk
		case .warning: theme.warningInk
		case .danger: theme.dangerText
		}
	}
}
