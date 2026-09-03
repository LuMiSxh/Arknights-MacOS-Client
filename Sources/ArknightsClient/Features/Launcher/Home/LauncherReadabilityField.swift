// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Adds the small top-leading contrast field behind launcher branding and status text.
struct LauncherReadabilityField: View {
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

	var body: some View {
		RadialGradient(
			colors: [.black, .black.opacity(0.68), .black.opacity(0.2), .clear],
			center: .topLeading,
			startRadius: 0,
			endRadius: 450
		)
		.frame(width: 680, height: 390, alignment: .topLeading)
		.blur(radius: reduceTransparency ? 0 : 3)
		.opacity(reduceTransparency ? 0.96 : 0.86)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}
}
