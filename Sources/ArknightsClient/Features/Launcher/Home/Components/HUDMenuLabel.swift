// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Compact accent chip used for HUD values that optionally open a menu.
struct HUDMenuLabel: View {
	let title: String
	let accentColor: Color
	var showsMenuIndicator = false

	var body: some View {
		HStack(spacing: 3) {
			Text(title)
			if showsMenuIndicator {
				Image(systemName: "chevron.up.chevron.down")
					.font(.caption2.bold())
					.accessibilityHidden(true)
			}
		}
		.font(.caption.weight(.semibold))
		.foregroundStyle(accentColor)
		.padding(.horizontal, 6)
		.padding(.vertical, 2)
		.background(accentColor.opacity(0.15), in: Capsule())
		.contentShape(Capsule())
	}
}
