// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct PresetGalleryLoadingView: View {
	let text: String

	var body: some View {
		VStack(spacing: 12) {
			ProgressView()
				.controlSize(.regular)
			Text(text)
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, minHeight: 240)
	}
}
