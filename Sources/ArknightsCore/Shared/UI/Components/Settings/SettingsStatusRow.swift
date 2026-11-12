// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// A blocked-permission row shown directly under the feature it blocks, only while that feature is on.
package struct SettingsStatusRow: View {
	let label: String
	var actionTitle: String?
	var action: (() -> Void)?
	@Environment(\.launcherTheme) private var theme

	package init(label: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
		self.label = label
		self.actionTitle = actionTitle
		self.action = action
	}

	package var body: some View {
		HStack(spacing: LauncherTokens.Spacing.control) {
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundStyle(theme.warningInk)
				.accessibilityHidden(true)
			Text(label)
				.font(.callout)
				.foregroundStyle(theme.textPrimary)
				.fixedSize(horizontal: false, vertical: true)
			Spacer(minLength: LauncherTokens.Spacing.control)
			if let actionTitle, let action {
				ExternalLinkButton(title: actionTitle, action: action)
			}
		}
	}
}
