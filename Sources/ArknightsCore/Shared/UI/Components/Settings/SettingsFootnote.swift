// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Explanatory text inside a panel that is not a row detail. Shows a fact or a disabled reason.
package struct SettingsFootnote: View {
	let text: String
	@Environment(\.launcherTheme) private var theme

	package init(_ text: String) {
		self.text = text
	}

	package var body: some View {
		Text(text)
			.font(.caption)
			.foregroundStyle(theme.textSecondary)
			.fixedSize(horizontal: false, vertical: true)
	}
}
