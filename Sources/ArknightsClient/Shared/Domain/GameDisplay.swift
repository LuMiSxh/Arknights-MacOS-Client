// SPDX-License-Identifier: MPL-2.0

import AppKit

/// How the game's frames reach a scaled (Retina) display.
enum GameRenderingMode: String, CaseIterable, Codable, Sendable {
	/// Wine RetinaMode: the game renders every backing-store pixel.
	case retina
	/// Wine renders in points and DXMT upscales each frame with MetalFX spatial scaling.
	case metalFX
	/// Wine renders in points and macOS stretches the window to the backing store.
	case lightweight
}

/// A width and height, either in macOS points (window size) or in game pixels.
struct GameDisplaySize: Codable, Hashable, Sendable {
	let width: Int
	let height: Int

	static let defaultWindow = GameDisplaySize(width: 1280, height: 720)
	static let validDimensions = 320...16_384

	/// Window sizes offered in the launcher, measured like macOS Display settings.
	static let windowPresets: [GameDisplaySize] = [
		(960, 540), (1024, 576), (1152, 648), (1280, 720), (1280, 800), (1440, 810),
		(1440, 900), (1600, 900), (1680, 1050), (1920, 1080), (1920, 1200), (2048, 1152),
		(2304, 1296), (2560, 1440), (2560, 1600), (3008, 1692), (3200, 1800), (3840, 2160),
	].map { GameDisplaySize(width: $0.0, height: $0.1) }

	init(width: Int, height: Int) {
		self.width = width
		self.height = height
	}

	init(_ resolution: GameResolution) {
		self.init(width: resolution.width, height: resolution.height)
	}

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		width = try container.decode(Int.self, forKey: .width)
		height = try container.decode(Int.self, forKey: .height)
		guard Self.validDimensions.contains(width), Self.validDimensions.contains(height) else {
			throw DecodingError.dataCorruptedError(
				forKey: .width, in: container, debugDescription: "Unsupported display size")
		}
	}

	var displayName: String { "\(width) × \(height)" }
	var pixelCount: Int { width * height }

	func fits(in other: GameDisplaySize) -> Bool {
		width <= other.width && height <= other.height
	}

	func scaled(by factor: Int) -> GameDisplaySize {
		GameDisplaySize(width: width * factor, height: height * factor)
	}

	/// Presets that fit `visibleSize` (in points), always keeping `current` selectable.
	static func windowOptions(
		fitting visibleSize: CGSize?, current: GameDisplaySize
	) -> [GameDisplaySize] {
		var options = windowPresets.filter { preset in
			guard let visibleSize else { return true }
			return CGFloat(preset.width) <= visibleSize.width
				&& CGFloat(preset.height) <= visibleSize.height
		}
		if !options.contains(current) {
			options.append(current)
			options.sort { ($0.width, $0.height) < ($1.width, $1.height) }
		}
		return options
	}
}

/// The display Arknights fills in fullscreen. Wine's Mac driver makes the display with the menu
/// bar its primary display, and the game opens fullscreen on the primary display. It is read at
/// every launch, so rearranging or swapping displays needs no setting change.
struct GameFullscreenDisplay: Equatable, Sendable {
	/// The display's size in macOS points.
	let pointSize: GameDisplaySize
	/// Backing-store pixels per point.
	let backingScale: Int

	@MainActor static var primary: GameFullscreenDisplay? {
		// The first screen is always the one with the menu bar, even when it is not focused.
		guard let screen = NSScreen.screens.first else { return nil }
		return GameFullscreenDisplay(
			pointSize: GameDisplaySize(
				width: Int(screen.frame.width.rounded()), height: Int(screen.frame.height.rounded())
			),
			backingScale: max(1, Int(screen.backingScaleFactor.rounded()))
		)
	}

	/// The display's full resolution, which Native fullscreen shows.
	var pixelSize: GameDisplaySize { pointSize.scaled(by: backingScale) }

	/// The pixels the game draws to show `shown`: all of them with Retina, otherwise one per
	/// point, which MetalFX or macOS then scales up.
	func drawnSize(showing shown: GameDisplaySize, retina: Bool) -> GameDisplaySize {
		guard !retina, backingScale > 1 else { return shown }
		return GameDisplaySize(
			width: shown.width / backingScale, height: shown.height / backingScale)
	}
}

/// How a launch renders on a display, so the launcher can describe it before the game starts.
struct GameDisplayPlan: Equatable, Sendable {
	enum Scaling: Equatable, Sendable {
		case native
		case metalFX
		case stretched
	}

	/// Pixels the game renders, or nil when Arknights' in-game settings decide.
	let renderSize: GameDisplaySize?
	/// Game pixels per macOS point; the in-game resolution is a window size times this value.
	let gamePixelsPerPoint: Int
	/// Pixels of the display's backing store per macOS point.
	let backingScale: Int
	let scaling: Scaling

	init(
		options: GameLaunchOptions, backingScaleFactor: CGFloat,
		fullscreenDisplay: GameFullscreenDisplay? = nil
	) {
		let backingScale = max(1, Int(backingScaleFactor.rounded()))
		self.backingScale = backingScale
		switch (backingScale, options.renderingMode) {
		case (1, _), (_, .retina): scaling = .native
		case (_, .metalFX): scaling = .metalFX
		case (_, .lightweight): scaling = .stretched
		}
		gamePixelsPerPoint = options.renderingMode == .retina ? backingScale : 1
		renderSize =
			if options.usesGameSettings {
				nil
			} else if options.displayMode == .fullscreen {
				options.fullscreenDrawnSize(on: fullscreenDisplay, retina: gamePixelsPerPoint > 1)
			} else {
				options.windowSize.scaled(by: gamePixelsPerPoint)
			}
	}
}
