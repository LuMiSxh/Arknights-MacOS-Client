// SPDX-License-Identifier: MPL-2.0

import Foundation

package enum PresetGalleryDestination: String, Identifiable, Sendable {
	case artwork
	case operatorIcons

	package var id: String { rawValue }

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
			"Choose one operator for both Dock icons."
		}
	}

	var searchPlaceholder: String {
		switch self {
		case .artwork: "Search artwork…"
		case .operatorIcons: "Search operators…"
		}
	}

	var loadingText: String {
		switch self {
		case .artwork: "Loading official wallpapers…"
		case .operatorIcons: "Loading operators…"
		}
	}

	var emptyText: String {
		switch self {
		case .artwork: "No matching artwork"
		case .operatorIcons: "No matching operators"
		}
	}
}
