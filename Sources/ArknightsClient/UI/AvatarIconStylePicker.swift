// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct AvatarIconStylePicker: View {
	@Binding var selection: AvatarIconStyle
	let accentColor: Color

	var body: some View {
		VStack(alignment: .leading, spacing: 5) {
			AdaptiveSegmentedControl(
				selection: $selection,
				options: AvatarIconStyle.allCases,
				accentColor: accentColor
			) { style in
				Text(style.displayName)
			}
			.accessibilityLabel("Icon Style")

			Text(selection.detail)
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}
}
