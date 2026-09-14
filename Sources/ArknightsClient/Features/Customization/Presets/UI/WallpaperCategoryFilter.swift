// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct WallpaperCategoryFilter: View {
	@Binding var selection: WallpaperCategory?
	let accentColor: Color
	/// Wallpaper counts for each category (and, under the `nil` key, the total across every
	/// category) among whatever's currently in play — the active search text and tag pills —
	/// so a count reflects what picking that option would actually show, not the whole catalog.
	let counts: [WallpaperCategory?: Int]
	/// Every operator identified among the currently shown wallpapers, most-featured first —
	/// picking one commits it as an exact-tag search pill, the same as typing its name would.
	let operatorCounts: [OperatorArtCount]
	let onSelectOperator: (String) -> Void

	var body: some View {
		GlassMenuPicker(
			selection: $selection,
			options: options,
			accentColor: accentColor,
			listTitle: { category in
				L10n.string(
					CustomizationStrings.wallpaperFilterOption(
						title(for: category), count: counts[category] ?? 0))
			},
			trailingMenuItems: {
				guard !operatorCounts.isEmpty else { return AnyView(EmptyView()) }
				return AnyView(
					Menu(L10n.string(CustomizationStrings.wallpaperFilterOperators)) {
						ForEach(operatorCounts) { entry in
							Button(
								L10n.string(
									CustomizationStrings.wallpaperFilterOption(
										entry.displayName, count: entry.count))
							) {
								onSelectOperator(entry.tag)
							}
						}
					}
				)
			}
		)
		.accessibilityLabel(Text(L10n.string(CustomizationStrings.wallpaperFilterLabel)))
	}

	private var options: [(value: WallpaperCategory?, title: String)] {
		([nil] + WallpaperCategory.allCases.map { $0 }).map { ($0, title(for: $0)) }
	}

	private func title(for category: WallpaperCategory?) -> String {
		category.map { L10n.string(CustomizationStrings.wallpaperCategory($0)) }
			?? L10n.string(CustomizationStrings.wallpaperFilterAll)
	}
}
