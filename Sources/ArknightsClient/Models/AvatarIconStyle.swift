// SPDX-License-Identifier: MPL-2.0

import Foundation

enum AvatarIconStyle: String, CaseIterable, Identifiable, Sendable {
	case rhodesDark
	case launcherGlass
	case gameIcon

	var id: String { rawValue }

	var displayName: String {
		switch self {
		case .rhodesDark: "Rhodes Dark"
		case .launcherGlass: "Launcher Icon"
		case .gameIcon: "Game Icon"
		}
	}

	var detail: String {
		switch self {
		case .rhodesDark:
			"Places the operator on a dark Rhodes Island plate with a glow sampled from the portrait."
		case .launcherGlass:
			"Uses the Arknights Client app background and follows Dynamic Theme when it is enabled."
		case .gameIcon:
			"Uses the official game's cyan, crystalline icon treatment behind the operator."
		}
	}
}
