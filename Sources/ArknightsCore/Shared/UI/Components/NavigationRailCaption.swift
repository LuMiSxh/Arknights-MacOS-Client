// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// The small heading that titles a group of navigation rail rows.
/// The small heading that titles a group of navigation rail rows.
package struct NavigationRailCaption: View {
	@Environment(\.launcherTheme) private var theme
	let text: String

	package init(text: String) {
		self.text = text
	}

	package var body: some View {
		Text(text)
			.font(.subheadline.weight(.medium))
			.foregroundStyle(theme.textTertiary)
	}
}
