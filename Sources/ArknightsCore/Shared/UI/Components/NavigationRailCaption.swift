// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// The small heading that titles a group of navigation rail rows.
package struct NavigationRailCaption: View {
	let text: String

	package init(text: String) {
		self.text = text
	}

	package var body: some View {
		Text(text)
			.font(.caption.weight(.medium))
			.foregroundStyle(.secondary)
	}
}
