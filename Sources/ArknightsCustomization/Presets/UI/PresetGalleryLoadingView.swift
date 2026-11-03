// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct PresetGalleryLoadingView: View {
	let text: String
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		VStack(spacing: 12) {
			ProgressView()
				.controlSize(.regular)
			Text(text)
				.font(.caption)
				.foregroundStyle(theme.textSecondary)
		}
		.frame(maxWidth: .infinity, minHeight: 240)
	}
}
