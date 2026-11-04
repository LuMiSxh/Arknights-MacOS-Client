// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct PresetGalleryHeader: View {
	let destination: PresetGalleryDestination
	let catalog: PresetCatalogService
	let customization: CustomizationController
	let avatars: [PresetAvatar]
	@Binding var showsIconStylePreview: Bool
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: LauncherTokens.Spacing.compact) {
				Text(destination.title)
					.font(.title3.weight(.medium))
				Text(destination.subtitle)
					.font(.caption)
					.foregroundStyle(theme.textSecondary)
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
						accentHue: customization.dynamicThemeHue
					)
				}
			}
		}
		.padding(.horizontal, LauncherTokens.Spacing.page)
		.padding(.vertical, LauncherTokens.Spacing.panel)
	}
}
