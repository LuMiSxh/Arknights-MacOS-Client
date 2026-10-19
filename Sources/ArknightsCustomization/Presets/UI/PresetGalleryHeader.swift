// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct PresetGalleryHeader: View {
	let destination: PresetGalleryDestination
	let catalog: PresetCatalogService
	let customization: CustomizationController
	let avatars: [PresetAvatar]
	@Binding var showsIconStylePreview: Bool

	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 3) {
				Text(destination.title)
					.font(.title3.bold())
				Text(destination.subtitle)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Spacer()
			if destination == .operatorIcons {
				CapsuleActionButton(
					title: "Preview Styles",
					systemImage: "dock.rectangle",
					tone: .neutral
				) {
					showsIconStylePreview = true
				}
				.controlSize(.small)
				.popover(isPresented: $showsIconStylePreview, arrowEdge: .top) {
					OperatorIconStylePreview(
						catalog: catalog,
						avatar: avatars.first,
						accentHue: customization.dynamicThemeHue,
						accentColor: customization.accentColor
					)
				}
			}
		}
		.padding(.horizontal, 24)
		.padding(.vertical, 16)
	}
}
