// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Page-level banner that explains why the whole page is locked. Place it above the first panel.
package struct SettingsLockBanner: View {
	let reason: String
	@Environment(\.launcherTheme) private var theme

	package init(reason: String) {
		self.reason = reason
	}

	package var body: some View {
		HStack(spacing: LauncherTokens.Spacing.control) {
			Image(systemName: "lock.fill")
				.foregroundStyle(theme.textSecondary)
				.accessibilityHidden(true)
			Text(reason)
				.font(.callout)
				.foregroundStyle(theme.textPrimary)
				.fixedSize(horizontal: false, vertical: true)
			Spacer(minLength: 0)
		}
		.padding(.horizontal, LauncherTokens.Spacing.content)
		.padding(.vertical, LauncherTokens.ControlPadding.settingsRowVertical)
		.frame(maxWidth: .infinity, alignment: .leading)
		.launcherSurface(.group)
		.accessibilityElement(children: .combine)
	}
}
