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
	/// Fullscreen game resolution in game pixels; matches the official client's choices.
	var resolution: GameResolution
	/// Windowed and borderless window size in macOS points.
	var windowSize: GameDisplaySize = .defaultWindow
	var usesGameSettings: Bool = false
	var renderingMode: GameRenderingMode = .retina
	var usesMetalPerformanceHUD: Bool = false
	var usesGameMode: Bool = false
	var synchronizationMode: WineSynchronizationMode = .msync

	static let `default` = GameLaunchOptions(
		displayMode: .windowed,
		resolution: .hd,
		windowSize: .defaultWindow,
		usesGameSettings: false,
		renderingMode: .retina,
		usesMetalPerformanceHUD: false,
		usesGameMode: false,
		synchronizationMode: .msync
	)

	private enum CodingKeys: String, CodingKey {
		case displayMode, resolution, windowSize, usesGameSettings, renderingMode
		case usesMetalPerformanceHUD, usesGameMode, synchronizationMode
		/// Pre-0.6.2 Retina toggle; still written so older launchers keep their pixel density.
		case usesHighResolutionMode
	}

	init(
		displayMode: GameDisplayMode,
		resolution: GameResolution,
		windowSize: GameDisplaySize = .defaultWindow,
		usesGameSettings: Bool = false,
		renderingMode: GameRenderingMode = .retina,
		usesMetalPerformanceHUD: Bool = false,
		usesGameMode: Bool = false,
		synchronizationMode: WineSynchronizationMode = .msync
	) {
		self.displayMode = displayMode
		self.resolution = resolution
		self.windowSize = windowSize
		self.usesGameSettings = usesGameSettings
		self.renderingMode = renderingMode
		self.usesMetalPerformanceHUD = usesMetalPerformanceHUD
		self.usesGameMode = usesGameMode
		self.synchronizationMode = synchronizationMode
	}

	/// Decodes each option independently, so one missing, retired, or malformed value falls
	/// back to its default instead of resetting every other launch option.
	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let defaults = Self.default
		func value<Value: Decodable>(_ key: CodingKeys, _ fallback: Value) -> Value {
			do {
				return try container.decodeIfPresent(Value.self, forKey: key) ?? fallback
			} catch {
				return fallback
			}
		}
		displayMode = value(.displayMode, defaults.displayMode)
		resolution = value(.resolution, defaults.resolution)
		// Stored options without this key predate it, when Arknights kept its own settings.
		usesGameSettings = value(.usesGameSettings, true)
		usesMetalPerformanceHUD = value(
			.usesMetalPerformanceHUD, defaults.usesMetalPerformanceHUD)
		usesGameMode = value(.usesGameMode, defaults.usesGameMode)
		synchronizationMode = value(.synchronizationMode, defaults.synchronizationMode)

		// Before 0.6.2 one resolution served both modes, in pixels while Retina was on.
		let legacyRetina = value(.usesHighResolutionMode, true)
		renderingMode = value(.renderingMode, legacyRetina ? .retina : .lightweight)
		let legacyWindow =
			!usesGameSettings && container.contains(.resolution)
			? Self.legacyWindowSize(for: resolution, retina: legacyRetina)
			: defaults.windowSize
		windowSize = value(.windowSize, legacyWindow)
	}

	func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(displayMode, forKey: .displayMode)
		try container.encode(resolution, forKey: .resolution)
		try container.encode(windowSize, forKey: .windowSize)
		try container.encode(usesGameSettings, forKey: .usesGameSettings)
		try container.encode(renderingMode, forKey: .renderingMode)
		try container.encode(renderingMode == .retina, forKey: .usesHighResolutionMode)
		try container.encode(usesMetalPerformanceHUD, forKey: .usesMetalPerformanceHUD)
		try container.encode(usesGameMode, forKey: .usesGameMode)
		try container.encode(synchronizationMode, forKey: .synchronizationMode)
	}

	/// Keeps the window a legacy pixel resolution produced, assuming a 2x Retina display.
	private static func legacyWindowSize(
		for resolution: GameResolution, retina: Bool
	) -> GameDisplaySize {
		let size = GameDisplaySize(resolution)
		guard retina else { return size }
		let halved = GameDisplaySize(width: size.width / 2, height: size.height / 2)
		guard GameDisplaySize.validDimensions.contains(halved.width),
			GameDisplaySize.validDimensions.contains(halved.height)
		else { return .defaultWindow }
		return halved
	}

	/// Unity standalone-player arguments supported by the Windows client. Windowed sizes are
	/// points, so they are multiplied by the game pixels Wine maps onto each point.
	func playerArguments(gamePixelsPerPoint: Int) -> [String] {
		guard !usesGameSettings else { return [] }
		let size =
			displayMode == .fullscreen
			? GameDisplaySize(resolution) : windowSize.scaled(by: max(1, gamePixelsPerPoint))
		var arguments = [
			"-screen-fullscreen", displayMode == .fullscreen ? "1" : "0",
			"-screen-width", String(size.width),
			"-screen-height", String(size.height),
		]
		if displayMode == .borderlessWindow { arguments.append("-popupwindow") }
		return arguments
	}
}
