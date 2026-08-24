// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Owns the gallery title and the optional operator-style preview action.
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
					title: L10n.string(CustomizationStrings.previewStyles),
					systemImage: "dock.rectangle",
					tone: .accent(customization.accentColor)
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
