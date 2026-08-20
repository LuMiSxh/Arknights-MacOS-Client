// SPDX-License-Identifier: MPL-2.0

import Foundation

enum PresetGalleryDestination: String, Identifiable {
	case artwork
	case launcherIcon
	case gameIcon

	var id: String { rawValue }

	var initialTab: PresetGalleryTab {
		self == .artwork ? .wallpapers : .avatars
	}
}
