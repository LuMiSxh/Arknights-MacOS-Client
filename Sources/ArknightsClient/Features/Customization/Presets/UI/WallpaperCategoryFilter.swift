// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct WallpaperCategoryFilter: View {
	@Binding var selection: WallpaperCategory?
	let accentColor: Color

	var body: some View {
		Menu {
			Button(L10n.string(CustomizationStrings.wallpaperFilterAll)) { selection = nil }
			ForEach(WallpaperCategory.allCases) { category in
				Button(L10n.string(CustomizationStrings.wallpaperCategory(category))) {
					selection = category
				}
			}
		} label: {
			Text(
				L10n.string(
					selection.map(CustomizationStrings.wallpaperCategory)
						?? CustomizationStrings.wallpaperFilterAll
				)
			)
			.lineLimit(1)
			.font(.callout)
			.padding(.horizontal, 10)
			.padding(.vertical, 7)
			.adaptiveGlassEffect(
				tint: accentColor.opacity(0.08),
				in: RoundedRectangle(cornerRadius: 10)
			)
			.overlay {
				RoundedRectangle(cornerRadius: 10)
					.strokeBorder(LauncherVisuals.controlTint.opacity(0.16), lineWidth: 1)
			}
		}
		.menuStyle(.borderlessButton)
		.fixedSize()
		.accessibilityLabel(Text(L10n.string(CustomizationStrings.wallpaperFilterLabel)))
	}
}
