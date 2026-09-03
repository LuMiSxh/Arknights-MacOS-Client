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
		case .borderlessWindow: "Borderless Window (Recommended)"
		}
	}
}

enum GameResolution: String, CaseIterable, Codable, Sendable {
	case ultraHD = "3840x2160"
	case quadHD = "2560x1440"
	case cinemaFullHD = "2048x1080"
	case wuxga = "1920x1200"
	case fullHD = "1920x1080"
	case wsxgaPlus = "1680x1050"
	case uxga = "1600x1200"
	case wsxga = "1600x1024"
	case hdPlus = "1600x900"
	case hdFourThree = "1440x1080"
	case hdWide = "1360x768"
	case sxgaPlus = "1280x960"
	case wxga = "1280x800"
	case wxgaWide = "1280x768"
	case hd = "1280x720"
	case scaledHD = "1176x664"
	case xgaPlus = "1152x864"
	case xga = "1024x768"
	case svga = "800x600"
	case ntscWide = "720x480"
	case sd = "640x480"

	var displayName: String { rawValue.replacing("x", with: " × ") }

	var width: Int { dimensions.width }
	var height: Int { dimensions.height }

	private var dimensions: (width: Int, height: Int) {
		let components = rawValue.split(separator: "x")
		guard components.count == 2,
			let width = Int(components[0]),
			let height = Int(components[1])
		else {
			preconditionFailure("Invalid built-in game resolution: \(rawValue)")
		}
		return (width, height)
	}
}

struct GameLaunchOptions: Codable, Sendable, Equatable {
	var displayMode: GameDisplayMode
	var resolution: GameResolution
	var usesGameSettings: Bool = true
	var usesHighResolutionMode: Bool = true
	var usesMetalPerformanceHUD: Bool = false
	var usesGameMode: Bool = false
	var synchronizationMode: WineSynchronizationMode = .msync

	static let `default` = GameLaunchOptions(
		displayMode: .windowed,
		resolution: .hd,
		usesGameSettings: true,
		usesHighResolutionMode: true,
		usesMetalPerformanceHUD: false,
		usesGameMode: false,
		synchronizationMode: .msync
	)

	private enum CodingKeys: String, CodingKey {
		case displayMode, resolution, usesGameSettings, usesHighResolutionMode
		case usesMetalPerformanceHUD, usesGameMode, synchronizationMode
	}

	init(
		displayMode: GameDisplayMode,
		resolution: GameResolution,
		usesGameSettings: Bool = true,
		usesHighResolutionMode: Bool = true,
		usesMetalPerformanceHUD: Bool = false,
		usesGameMode: Bool = false,
		synchronizationMode: WineSynchronizationMode = .msync
	) {
		self.displayMode = displayMode
		self.resolution = resolution
		self.usesGameSettings = usesGameSettings
		self.usesHighResolutionMode = usesHighResolutionMode
		self.usesMetalPerformanceHUD = usesMetalPerformanceHUD
		self.usesGameMode = usesGameMode
		self.synchronizationMode = synchronizationMode
	}

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		displayMode = try container.decode(GameDisplayMode.self, forKey: .displayMode)
		resolution = try container.decode(GameResolution.self, forKey: .resolution)
		usesGameSettings =
			try container.decodeIfPresent(Bool.self, forKey: .usesGameSettings) ?? true
		usesHighResolutionMode =
			try container.decodeIfPresent(Bool.self, forKey: .usesHighResolutionMode) ?? true
		usesMetalPerformanceHUD =
			try container.decodeIfPresent(Bool.self, forKey: .usesMetalPerformanceHUD) ?? false
		usesGameMode = try container.decodeIfPresent(Bool.self, forKey: .usesGameMode) ?? false
		synchronizationMode =
			try container.decodeIfPresent(
				WineSynchronizationMode.self, forKey: .synchronizationMode) ?? .msync
	}

	/// Unity standalone-player arguments supported by the Windows client.
	var playerArguments: [String] {
		guard !usesGameSettings else { return [] }
		var arguments = [
			"-screen-fullscreen", displayMode == .fullscreen ? "1" : "0",
			"-screen-width", String(resolution.width),
			"-screen-height", String(resolution.height),
		]
		if displayMode == .borderlessWindow { arguments.append("-popupwindow") }
		return arguments
	}
}
