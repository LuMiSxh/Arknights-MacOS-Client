// SPDX-License-Identifier: MPL-2.0

import Foundation

enum PresetGalleryDestination: String, Identifiable {
	case artwork
	case operatorIcons

	var id: String { rawValue }

	var title: String {
		switch self {
		case .artwork: "Artwork Gallery"
		case .operatorIcons: "Choose an Operator"
		}
	}

	var subtitle: String {
		switch self {
		case .artwork:
			"Choose a background for the launcher."
		case .operatorIcons:
			"One choice creates the paired Launcher and Game Dock icons shown below."
		}
	}

	var searchPlaceholder: String {
		switch self {
		case .artwork: "Search artwork…"
		case .operatorIcons: "Search operators…"
		}
	}
}
