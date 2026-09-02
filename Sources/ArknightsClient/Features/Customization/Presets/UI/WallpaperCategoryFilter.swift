// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct WallpaperCategoryFilter: View {
	@Binding var selection: WallpaperCategory?
	let accentColor: Color

	var body: some View {
		GlassMenuPicker(
			selection: $selection,
			options: options,
			accentColor: accentColor
		)
		.accessibilityLabel(Text(L10n.string(CustomizationStrings.wallpaperFilterLabel)))
	}

	private var options: [(value: WallpaperCategory?, title: String)] {
		[(nil, L10n.string(CustomizationStrings.wallpaperFilterAll))]
			+ WallpaperCategory.allCases.map {
				($0, L10n.string(CustomizationStrings.wallpaperCategory($0)))
			}
	}
}
