// SPDX-License-Identifier: MPL-2.0

import AppKit

package enum GameRenderingMode: String, CaseIterable, Codable, Sendable {
	/// Wine RetinaMode: the game renders every backing-store pixel.
	case retina
	/// Wine renders in points and DXMT upscales each frame with MetalFX spatial scaling.
	case metalFX
	/// Wine renders in points and macOS stretches the window to the backing store.
	case standard
}

package struct GameDisplaySize: Codable, Hashable, Sendable {
	package let width: Int
	package let height: Int

	package static let defaultWindow = GameDisplaySize(width: 1280, height: 720)
	static let validDimensions = 320...16_384

	static let windowPresets: [GameDisplaySize] = [
		(960, 540), (1024, 576), (1152, 648), (1280, 720), (1280, 800), (1440, 810),
		(1440, 900), (1600, 900), (1680, 1050), (1920, 1080), (1920, 1200), (2048, 1152),
		(2304, 1296), (2560, 1440), (2560, 1600), (3008, 1692), (3200, 1800), (3840, 2160),
	].map { GameDisplaySize(width: $0.0, height: $0.1) }

	package init(width: Int, height: Int) {
		self.width = width
		self.height = height
	}

	// Resolutions of the official client, largest first. `GameLaunchOptions.resolution` is one of these.
	static let officialResolutions: [GameDisplaySize] = [
		(3840, 2160), (2560, 1440), (2048, 1080), (1920, 1200), (1920, 1080), (1680, 1050),
		(1600, 1200), (1600, 1024), (1600, 900), (1440, 1080), (1360, 768), (1280, 960),
		(1280, 800), (1280, 768), (1280, 720), (1176, 664), (1152, 864), (1024, 768), (800, 600),
		(720, 480), (640, 480),
	].map { GameDisplaySize(width: $0.0, height: $0.1) }
	package static let ultraHD = GameDisplaySize(width: 3840, height: 2160)
	package static let quadHD = GameDisplaySize(width: 2560, height: 1440)
	package static let fullHD = GameDisplaySize(width: 1920, height: 1080)
	package static let hd = GameDisplaySize(width: 1280, height: 720)

	static func largestOfficial(fitting size: GameDisplaySize) -> GameDisplaySize? {
		officialResolutions.filter { $0.fits(in: size) }.max { $0.pixelCount < $1.pixelCount }
	}

	/// Stored as "WIDTHxHEIGHT".
	package var storageValue: String { "\(width)x\(height)" }

	init?(storageValue: String) {
		let components = storageValue.split(separator: "x")
		guard components.count == 2, let width = Int(components[0]),
			let height = Int(components[1]),
			Self.validDimensions.contains(width), Self.validDimensions.contains(height)
		else { return nil }
		self.init(width: width, height: height)
	}

	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		width = try container.decode(Int.self, forKey: .width)
		height = try container.decode(Int.self, forKey: .height)
		guard Self.validDimensions.contains(width), Self.validDimensions.contains(height) else {
			throw DecodingError.dataCorruptedError(
				forKey: .width, in: container, debugDescription: "Unsupported display size")
		}
	}

	package var displayName: String { "\(width) × \(height)" }
	var pixelCount: Int { width * height }

	func fits(in other: GameDisplaySize) -> Bool {
		width <= other.width && height <= other.height
	}

	package func scaled(by factor: Int) -> GameDisplaySize {
		GameDisplaySize(width: width * factor, height: height * factor)
	}

	/// Presets that fit `visibleSize` (in points), always keeping `current` selectable.
	package static func windowOptions(
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
package struct GameFullscreenDisplay: Equatable, Sendable {
	let pointSize: GameDisplaySize
	let backingScale: Int
	/// Points the notch covers at the top of the display; zero without a notch.
	var notchHeight = 0

	@MainActor package static var primary: GameFullscreenDisplay? {
		// The first screen is always the one with the menu bar, even when it is not focused.
		guard let screen = NSScreen.screens.first else { return nil }
		return GameFullscreenDisplay(
			pointSize: GameDisplaySize(
				width: Int(screen.frame.width.rounded()), height: Int(screen.frame.height.rounded())
			),
			backingScale: max(1, Int(screen.backingScaleFactor.rounded())),
			notchHeight: Int(screen.safeAreaInsets.top.rounded())
		)
	}

	package var pixelSize: GameDisplaySize { pointSize.scaled(by: backingScale) }

	/// The content area of a native fullscreen Space, which leaves the notch area empty.
	package var nativeSpaceContent: GameFullscreenDisplay {
		GameFullscreenDisplay(
			pointSize: GameDisplaySize(
				width: pointSize.width, height: pointSize.height - notchHeight
			),
			backingScale: backingScale
		)
	}

	// The pixels the game draws to show `shown`: all of them with Retina, otherwise one per
	// point, which MetalFX or macOS then scales up.
	func drawnSize(showing shown: GameDisplaySize, retina: Bool) -> GameDisplaySize {
		guard !retina, backingScale > 1 else { return shown }
		return GameDisplaySize(
			width: shown.width / backingScale, height: shown.height / backingScale)
	}
}

package struct GameDisplayPlan: Equatable, Sendable {
	package enum Scaling: Equatable, Sendable {
		case native
		case metalFX
		case stretched
	}

	/// Pixels the game renders, or nil when Arknights' in-game settings decide.
	package let renderSize: GameDisplaySize?
	/// Game pixels per macOS point; the in-game resolution is a window size times this value.
	package let gamePixelsPerPoint: Int
	let backingScale: Int
	package let scaling: Scaling

	package init(
		options: GameLaunchOptions, backingScaleFactor: CGFloat,
		fullscreenDisplay: GameFullscreenDisplay? = nil
	) {
		let backingScale = max(1, Int(backingScaleFactor.rounded()))
		self.backingScale = backingScale
		switch (backingScale, options.renderingMode) {
		case (1, _), (_, .retina): scaling = .native
		case (_, .metalFX): scaling = .metalFX
		case (_, .standard): scaling = .stretched
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
