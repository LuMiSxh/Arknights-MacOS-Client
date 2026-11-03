// SPDX-License-Identifier: MPL-2.0

import Foundation

package enum GameDisplayMode: String, CaseIterable, Codable, Sendable {
	case fullscreen
	case windowed
	case borderlessWindow

	package var displayName: String {
		switch self {
		case .fullscreen: "Fullscreen"
		case .windowed: "Windowed"
		case .borderlessWindow: "Borderless Window"
		}
	}
}

package struct GameLaunchOptions: Codable, Sendable, Equatable {
	package var displayMode: GameDisplayMode
	/// The official resolution closest to `fullscreenResolution`, the only fullscreen size
	/// launchers before 0.7.0 read, and the fallback when the display is unknown.
	package var resolution: GameDisplaySize
	/// The resolution fullscreen shows, like a game's output resolution. Native follows the
	/// fullscreen display, so displays beyond 4K or with uncommon sizes are not scaled unevenly.
	package var fullscreenResolution: GameFullscreenResolution
	package var windowSize: GameDisplaySize
	package var usesGameSettings: Bool
	package var renderingMode: GameRenderingMode
	package var usesMetalPerformanceHUD: Bool
	package var usesGameMode: Bool
	package var synchronizationMode: WineSynchronizationMode
	package var frameRateLimit: GameFrameRateLimit

	// The initializer holds the only copy of each default; `default` is built from it.
	package static let `default` = GameLaunchOptions(displayMode: .windowed, resolution: .hd)

	private enum CodingKeys: String, CodingKey {
		case displayMode, resolution, fullscreenResolution, windowSize, usesGameSettings
		case renderingMode
		case usesMetalPerformanceHUD, usesGameMode, synchronizationMode, frameRateLimit
		/// Pre-0.7.0 Retina toggle; still written so older launchers keep their pixel density.
		case usesHighResolutionMode
	}

	init(
		displayMode: GameDisplayMode,
		resolution: GameDisplaySize,
		fullscreenResolution: GameFullscreenResolution? = nil,
		windowSize: GameDisplaySize = .defaultWindow,
		usesGameSettings: Bool = false,
		renderingMode: GameRenderingMode = .retina,
		usesMetalPerformanceHUD: Bool = false,
		usesGameMode: Bool = false,
		synchronizationMode: WineSynchronizationMode = .msync,
		frameRateLimit: GameFrameRateLimit = .fps120
	) {
		self.displayMode = displayMode
		self.resolution = resolution
		self.fullscreenResolution = fullscreenResolution ?? .fixed(resolution)
		self.windowSize = windowSize
		self.usesGameSettings = usesGameSettings
		self.renderingMode = renderingMode
		self.usesMetalPerformanceHUD = usesMetalPerformanceHUD
		self.usesGameMode = usesGameMode
		self.synchronizationMode = synchronizationMode
		self.frameRateLimit = frameRateLimit
	}

	/// Decodes each option independently, so one missing, retired, or malformed value falls
	/// back to its default instead of resetting every other launch option.
	package init(from decoder: any Decoder) throws {
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
		let storedResolution = GameDisplaySize(
			storageValue: value(.resolution, defaults.resolution.storageValue))
		resolution =
			storedResolution.flatMap {
				GameDisplaySize.officialResolutions.contains($0) ? $0 : nil
			} ?? defaults.resolution
		fullscreenResolution = value(.fullscreenResolution, .fixed(resolution))
		usesGameSettings = value(.usesGameSettings, defaults.usesGameSettings)
		usesMetalPerformanceHUD = value(
			.usesMetalPerformanceHUD, defaults.usesMetalPerformanceHUD)
		usesGameMode = value(.usesGameMode, defaults.usesGameMode)
		synchronizationMode = value(.synchronizationMode, defaults.synchronizationMode)
		frameRateLimit = value(.frameRateLimit, defaults.frameRateLimit)

		renderingMode = value(.renderingMode, defaults.renderingMode)
		windowSize = value(.windowSize, defaults.windowSize)
	}

	package func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(displayMode, forKey: .displayMode)
		try container.encode(resolution.storageValue, forKey: .resolution)
		try container.encode(fullscreenResolution, forKey: .fullscreenResolution)
		try container.encode(windowSize, forKey: .windowSize)
		try container.encode(usesGameSettings, forKey: .usesGameSettings)
		try container.encode(renderingMode, forKey: .renderingMode)
		try container.encode(renderingMode == .retina, forKey: .usesHighResolutionMode)
		try container.encode(usesMetalPerformanceHUD, forKey: .usesMetalPerformanceHUD)
		try container.encode(usesGameMode, forKey: .usesGameMode)
		try container.encode(synchronizationMode, forKey: .synchronizationMode)
		try container.encode(frameRateLimit, forKey: .frameRateLimit)
	}

	func fullscreenSize(native: GameDisplaySize?) -> GameDisplaySize {
		switch fullscreenResolution {
		case .native: native ?? resolution
		case .fixed(let size): size
		}
	}

	// The pixels the game draws in fullscreen. MetalFX and Standard draw one pixel per point
	// and scale up; without a known display the shown size is drawn as is.
	func fullscreenDrawnSize(on display: GameFullscreenDisplay?, retina: Bool) -> GameDisplaySize {
		let shown = fullscreenSize(native: display?.pixelSize)
		return display?.drawnSize(showing: shown, retina: retina) ?? shown
	}

	/// Picks a fullscreen size and keeps `resolution` on the closest official one.
	package mutating func selectFullscreen(
		_ choice: GameFullscreenResolution, native: GameDisplaySize?
	) {
		fullscreenResolution = choice
		if let official = GameDisplaySize.largestOfficial(fitting: fullscreenSize(native: native)) {
			resolution = official
		}
	}

	/// The windowed size the game opens with. A size larger than the screen or the custom
	/// maximum is scaled down; the stored size stays unchanged.
	package func launchWindowSize(on screen: GameScreenMetrics?) -> GameDisplaySize {
		let maximum = AppConstants.Game.customWindowMaximumDimension
		var bounds = GameDisplaySize(width: maximum, height: maximum)
		if let screen {
			// Fills the screen below the title bar, like the Fill screen choice.
			let fill = GameWindowSizeChoice.fillScreen.size(on: screen)
			bounds = GameDisplaySize(
				width: min(fill.width, maximum), height: min(fill.height, maximum))
		}
		return windowSize.fitted(into: bounds)
	}

	/// Unity standalone-player arguments supported by the Windows client. Windowed sizes are
	/// points, so they are fitted to `screen` and multiplied by the game pixels Wine maps onto
	/// each point.
	package func playerArguments(
		gamePixelsPerPoint: Int, fullscreenDisplay: GameFullscreenDisplay? = nil,
		screen: GameScreenMetrics? = nil
	) -> [String] {
		guard !usesGameSettings else { return [] }
		let fullscreen = displayMode == .fullscreen
		let size =
			fullscreen
			? fullscreenDrawnSize(on: fullscreenDisplay, retina: gamePixelsPerPoint > 1)
			: launchWindowSize(on: screen).scaled(by: max(1, gamePixelsPerPoint))
		var arguments = [
			"-screen-fullscreen", fullscreen ? "1" : "0",
			"-screen-width", String(size.width),
			"-screen-height", String(size.height),
		]
		// Native sizes come from the primary display, so keep the game from reopening on the
		// display Unity remembers from an earlier session.
		if fullscreen && fullscreenResolution == .native && fullscreenDisplay != nil {
			arguments += ["-monitor", "1"]
		}
		if displayMode == .borderlessWindow { arguments.append("-popupwindow") }
		return arguments
	}
}
