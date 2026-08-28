// SPDX-License-Identifier: MPL-2.0

#if DEBUG
	import Foundation

	enum DeveloperScenario: String, CaseIterable, Identifiable {
		case ready
		case launcherUpdate = "launcher-update"
		case announcement
		case customPopup = "custom-popup"
		case gameUpdate = "game-update"
		case downloading
		case paused
		case launching
		case failure
		case accessibility = "accessibility"
		case onboardingRosetta = "onboarding-rosetta"

		var id: String { rawValue }

		init?(arguments: [String]) {
			guard let flag = arguments.firstIndex(of: "--developer-scenario") else { return nil }
			guard arguments.indices.contains(flag + 1),
				let scenario = Self(rawValue: arguments[flag + 1])
			else {
				// Keep stale or malformed preview commands isolated instead of falling back to
				// normal startup, which could contact services or touch a real installation.
				self = .ready
				return
			}
			self = scenario
		}

		var title: String {
			switch self {
			case .ready: "Ready"
			case .launcherUpdate: "Launcher update"
			case .announcement: "Announcement"
			case .customPopup: "Custom popup"
			case .gameUpdate: "Game update"
			case .downloading: "Downloading"
			case .paused: "Paused download"
			case .launching: "Starting game"
			case .failure: "Failure"
			case .accessibility: "Accessibility & layout"
			case .onboardingRosetta: "Onboarding · Rosetta missing"
			}
		}

		var detail: String {
			switch self {
			case .ready: "An installed and current game client."
			case .launcherUpdate: "A newer launcher update reported by Sparkle."
			case .announcement: "A one-time message controlled by announcements.json."
			case .customPopup: "Type Markdown below and show it as the real popup."
			case .gameUpdate: "An installed game with newer files available."
			case .downloading: "An active game update at 43 percent."
			case .paused: "A resumable update after the user selected Pause."
			case .launching: "The Windows runtime is starting; Stop is disabled."
			case .failure: "A runtime failure displayed in the status capsule."
			case .accessibility:
				"Long status text for keyboard, Dynamic Type, Reduce Motion, and contrast checks."
			case .onboardingRosetta: "First-run recovery when macOS removed Rosetta."
			}
		}
	}
#endif
