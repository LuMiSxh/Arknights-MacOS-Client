// SPDX-License-Identifier: MPL-2.0

import Foundation

enum PresetGalleryDestination: String, Identifiable {
	case artwork
	case launcherIcon
	case gameIcon

	var id: String { rawValue }

	var title: String {
		switch self {
		case .artwork: "Artwork Gallery"
		case .launcherIcon: "Choose a Launcher Operator"
		case .gameIcon: "Choose a Game Operator"
		}
	}

	var subtitle: String {
		switch self {
		case .artwork:
			"Choose a background for the launcher."
		case .launcherIcon:
			"Creates a Launcher-style icon and changes only the launcher."
		case .gameIcon:
			"Creates a Game-style icon and changes only the running game."
		}
	}

	var searchPlaceholder: String {
		switch self {
		case .artwork: "Search artwork…"
		case .launcherIcon, .gameIcon: "Search operators…"
		}
	}

	var iconTreatment: OperatorIconTreatment? {
		switch self {
		case .artwork: nil
		case .launcherIcon: .launcher
		case .gameIcon: .game
		}
	}
}
