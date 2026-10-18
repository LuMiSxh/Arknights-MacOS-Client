// SPDX-License-Identifier: MPL-2.0

// Selection is view state only and is never persisted.
enum SettingsSection: String, CaseIterable, Identifiable {
	case game
	case appearance
	case audio
	case updates
	case installation
	case storage
	case statistics
	case about
	#if DEBUG
		case developer
	#endif

	static let initial = SettingsSection.game

	var id: String { rawValue }

	var title: String {
		switch self {
		case .game: "Game"
		case .appearance: "Appearance"
		case .audio: "Audio"
		case .updates: "Updates"
		case .installation: "Installation"
		case .storage: "Storage"
		case .statistics: "Playtime"
		case .about: "About"
		#if DEBUG
			case .developer: "Developer"
		#endif
		}
	}

	var systemImage: String {
		switch self {
		case .game: "gamecontroller"
		case .appearance: "paintbrush"
		case .audio: "music.note"
		case .updates: "arrow.trianglehead.2.clockwise"
		case .installation: "externaldrive"
		case .storage: "internaldrive"
		case .statistics: "chart.bar.xaxis"
		case .about: "info.circle"
		#if DEBUG
			case .developer: "hammer"
		#endif
		}
	}
}
