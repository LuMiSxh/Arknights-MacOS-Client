// SPDX-License-Identifier: MPL-2.0

/// Sidebar group. The caption labels the group in the settings rail.
enum SettingsGroup: CaseIterable {
	case arknights
	case launcher
	case general

	var caption: String? {
		switch self {
		case .arknights: "ARKNIGHTS"
		case .launcher: "LAUNCHER"
		case .general: "SUPPORT"
		}
	}
}

// Selection is view state only and is never persisted.
enum SettingsSection: String, CaseIterable, Identifiable {
	case game
	case servers
	case storage
	case statistics
	case appearance
	case integration
	case updates
	case help
	case about
	#if DEBUG
		case developer
	#endif

	static let initial = SettingsSection.game

	var id: String { rawValue }

	var group: SettingsGroup {
		switch self {
		case .game, .servers, .storage, .statistics: .arknights
		case .appearance, .integration, .updates: .launcher
		default: .general
		}
	}

	var title: String {
		switch self {
		case .game: "Game"
		case .appearance: "Appearance"
		case .integration: "Integration"
		case .updates: "Updates"
		case .servers: "Servers"
		case .storage: "Storage"
		case .statistics: "Playtime"
		case .help: "Help"
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
		case .integration: "puzzlepiece.extension"
		case .updates: "arrow.trianglehead.2.clockwise"
		case .servers: "globe"
		case .storage: "internaldrive"
		case .statistics: "chart.bar.xaxis"
		case .help: "lifepreserver"
		case .about: "info.circle"
		#if DEBUG
			case .developer: "hammer"
		#endif
		}
	}
}
