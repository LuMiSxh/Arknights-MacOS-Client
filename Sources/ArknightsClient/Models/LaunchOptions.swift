// SPDX-License-Identifier: MPL-2.0

import Foundation

enum GameDisplayMode: String, CaseIterable, Codable, Sendable {
	case fullscreen
	case windowed
	case borderlessWindow

	var displayName: String {
		switch self {
		case .fullscreen: "Fullscreen"
		case .windowed: "Windowed"
		case .borderlessWindow: "Borderless Window"
		}
	}
}

enum GameResolution: String, CaseIterable, Codable, Sendable {
	case sd = "640x480"
	case hd = "1280x720"
	case fullHD = "1920x1080"
	case quadHD = "2560x1440"
	case ultraHD = "3840x2160"

	var displayName: String { rawValue.replacingOccurrences(of: "x", with: " × ") }

	var width: Int {
		switch self {
		case .sd: 640
		case .hd: 1280
		case .fullHD: 1920
		case .quadHD: 2560
		case .ultraHD: 3840
		}
	}

	var height: Int {
		switch self {
		case .sd: 480
		case .hd: 720
		case .fullHD: 1080
		case .quadHD: 1440
		case .ultraHD: 2160
		}
	}
}

struct GameLaunchOptions: Codable, Sendable, Equatable {
	var displayMode: GameDisplayMode
	var resolution: GameResolution

	static let `default` = GameLaunchOptions(displayMode: .windowed, resolution: .hd)

	/// Unity standalone-player arguments supported by the Windows client.
	var playerArguments: [String] {
		var arguments = [
			"-screen-fullscreen", displayMode == .fullscreen ? "1" : "0",
			"-screen-width", String(resolution.width),
			"-screen-height", String(resolution.height),
		]

		if displayMode == .borderlessWindow {
			arguments.append("-popupwindow")
		}

		return arguments
	}
}
