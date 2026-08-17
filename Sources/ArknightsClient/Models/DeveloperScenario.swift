// SPDX-License-Identifier: MPL-2.0

#if DEBUG
	import Foundation

	enum DeveloperScenario: String, CaseIterable, Identifiable {
		case ready
		case launcherUpdate = "launcher-update"
		case announcement
		case customPopup = "custom-popup"
		case yostarNotice = "yostar-notice"
		case gameUpdate = "game-update"
		case downloading
		case paused
		case migrating
		case launching
		case running
		case failure
		case notInstalled = "not-installed"

		var id: String { rawValue }

		init?(arguments: [String]) {
			guard let flag = arguments.firstIndex(of: "--developer-scenario"),
				arguments.indices.contains(flag + 1)
			else { return nil }
			self.init(rawValue: arguments[flag + 1])
		}

		var title: String {
			switch self {
			case .ready: "Ready"
			case .launcherUpdate: "Launcher update"
			case .announcement: "Announcement"
			case .customPopup: "Custom popup"
			case .yostarNotice: "Yostar notice"
			case .gameUpdate: "Game update"
			case .downloading: "Downloading"
			case .paused: "Paused download"
			case .migrating: "Preparing Wine runtime"
			case .launching: "Starting game"
			case .running: "Game running"
			case .failure: "Failure"
			case .notInstalled: "Not installed"
			}
		}

		var detail: String {
			switch self {
			case .ready: "An installed and current game client."
			case .launcherUpdate: "A newer launcher release with release notes."
			case .announcement: "A one-time message controlled by announcements.json."
			case .customPopup: "Markdown loaded from the file passed to just preview-popup."
			case .yostarNotice: "An official notice returned by the game API."
			case .gameUpdate: "An installed game with newer files available."
			case .downloading: "An active game update at 43 percent."
			case .paused: "A resumable update after the user selected Pause."
			case .migrating: "The Wine prefix is replaying setup after Force Migration."
			case .launching: "The Windows runtime is starting; Stop is disabled."
			case .running: "The game is running and can be stopped."
			case .failure: "A runtime failure displayed in the status capsule."
			case .notInstalled: "A fresh launcher before the game is installed."
			}
		}
	}
#endif
