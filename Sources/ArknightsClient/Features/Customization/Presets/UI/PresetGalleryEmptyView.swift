// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct PresetGalleryEmptyView: View {
	let text: LocalizedStringResource
	let systemImage: String

	var body: some View {
		ContentUnavailableView {
			Label {
				Text(L10n.string(text))
			} icon: {
				Image(systemName: systemImage)
			}
		}
		.frame(maxWidth: .infinity, minHeight: 240)
	}
}
