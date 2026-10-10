// SPDX-License-Identifier: MPL-2.0

/// Pages of the settings sheet in navigation order. Selection is view state only, never persisted.
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

	/// What the sheet shows when it opens.
	static let initial = SettingsSection.game

	var id: String { rawValue }

	var title: String {
		switch self {
		case .game: SettingsStrings.navigationGame
		case .appearance: SettingsStrings.navigationAppearance
		case .audio: SettingsStrings.navigationAudio
		case .updates: SettingsStrings.navigationUpdates
		case .installation: SettingsStrings.navigationInstallation
		case .storage: SettingsStrings.navigationStorage
		case .statistics: SettingsStrings.navigationStatistics
		case .about: SettingsStrings.navigationAbout
		#if DEBUG
			case .developer: SettingsStrings.navigationDeveloper
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
