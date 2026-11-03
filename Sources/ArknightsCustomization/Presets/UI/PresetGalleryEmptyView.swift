// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct PresetGalleryEmptyView: View {
	let text: String
	let systemImage: String

	var body: some View {
		ContentUnavailableView {
			Label {
				Text(text)
			} icon: {
				Image(systemName: systemImage)
			}
		}
		.frame(maxWidth: .infinity, minHeight: 240)
	}
}
