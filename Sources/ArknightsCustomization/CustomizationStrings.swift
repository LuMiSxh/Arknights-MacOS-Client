// SPDX-License-Identifier: MPL-2.0

enum CustomizationStrings {
	static let applying = "Applying…"

	static func wallpaperCategory(_ category: WallpaperCategory) -> String {
		switch category {
		case .story: "Story"
		case .commemorative: "Commemorative"
		case .celebration: "Celebration"
		case .holiday: "Holiday"
		}
	}

}
