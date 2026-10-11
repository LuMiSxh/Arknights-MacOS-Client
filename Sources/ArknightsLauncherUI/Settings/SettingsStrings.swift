// SPDX-License-Identifier: MPL-2.0

import ArknightsCore

/// English text owned by the launcher settings experience. Titles and details speak to players;
/// technical background lives in `*Help` tooltips and the Advanced game panel.
enum SettingsStrings {
	package static let cancel = "Cancel"
	static let useDefault = "Use Default"

	static func displayMode(_ mode: GameDisplayMode) -> String {
		switch mode {
		case .fullscreen: "Fullscreen"
		case .windowed: "In a window"
		case .borderlessWindow: "Borderless window"
		}
	}

	static func displayModeDetail(_ mode: GameDisplayMode) -> String {
		switch mode {
		case .fullscreen: "Arknights fills your whole screen."
		case .windowed: "Arknights opens in a window you can move around."
		case .borderlessWindow: "Arknights opens in a window without a title bar."
		}
	}

	static func windowSizeTitle(_ choice: GameWindowSizeChoice) -> String {
		switch choice {
		case .fillScreen: "Fill my screen"
		case .leaveRoom: "Leave room for other apps"
		}
	}

	/// `choice` is nil for an exact size picked from the list.
	static func windowSizeDetail(_ choice: GameWindowSizeChoice?) -> String {
		switch choice {
		case .fillScreen?: "Fills your screen, title bar included."
		case .leaveRoom?: "Leaves space for other apps on your screen."
		case nil: "A window of the exact size you picked."
		}
	}

	/// For example "Balanced · 2560 × 1440 (WQHD)".
	static func fullscreenDetailTitle(
		_ detail: GameFullscreenDetail, resolution: GameFullscreenResolution
	) -> String {
		let size =
			switch resolution {
			case .native: nativeResolution
			case .fixed(let size): resolutionTitle(size)
			}
		return switch detail {
		case .full: "Full detail · \(size) (recommended)"
		case .balanced: "Balanced · \(size)"
		case .lighter: "Lighter · \(size)"
		}
	}

	/// `detail` is nil for an exact resolution picked from the submenu.
	static func fullscreenDetailDetail(_ detail: GameFullscreenDetail?) -> String {
		switch detail {
		case .full?: "Uses every pixel of your screen. Best on most Macs."
		case .balanced?: "A little easier on your Mac, still crisp."
		case .lighter?: "Easiest on your Mac, but the picture looks softer."
		case nil: "A resolution you picked yourself."
		}
	}

	static let nativeResolution = "Native"

	static func fullscreenResolutionTitle(_ choice: GameFullscreenResolution) -> String {
		switch choice {
		case .native: nativeResolution
		case .fixed(let size): size.displayName
		}
	}

	/// For example "Native (6016 × 3384)", like games label the display's own resolution.
	static func nativeResolutionTitle(_ size: GameDisplaySize?) -> String {
		size.map { "\(nativeResolution) (\($0.displayName))" } ?? nativeResolution
	}

	/// For example "2560 × 1440 (WQHD)"; resolutions without a common name stay plain.
	static func resolutionTitle(_ size: GameDisplaySize) -> String {
		standardName(size).map { "\(size.displayName) (\($0))" } ?? size.displayName
	}

	/// Common names, only for the exact resolutions they stand for.
	static func standardName(_ size: GameDisplaySize) -> String? {
		switch (size.width, size.height) {
		case (1280, 720): "HD"
		case (1920, 1080): "Full HD"
		case (2560, 1440): "WQHD"
		case (3840, 2160): "4K"
		case (5120, 2880): "5K"
		case (6016, 3384): "6K"
		case (7680, 4320): "8K"
		default: nil
		}
	}

	static func pictureTitle(_ mode: GameRenderingMode) -> String {
		switch mode {
		case .retina: "The sharpest picture · Retina"
		case .metalFX: "Smooth play on big screens · MetalFX"
		case .lightweight: "Longer battery life · Lightweight"
		}
	}

	static func pictureDetail(_ mode: GameRenderingMode) -> String {
		switch mode {
		case .retina: "Looks sharpest, but asks the most of your Mac."
		case .metalFX: "Stays smooth on large screens; text looks slightly softer."
		case .lightweight: "Easiest on your battery, but the picture looks softer."
		}
	}

	static func pointerDetail(usesMacPointer: Bool) -> String {
		usesMacPointer
			? "The macOS hardware cursor follows your mouse without delay."
			: "The game draws its own software cursor, which can lag slightly."
	}

	static func scalingDetail(_ scaling: GameDisplayPlan.Scaling) -> String {
		switch scaling {
		case .native: "Shown without scaling."
		case .metalFX: "MetalFX upscales it to fit your screen."
		case .stretched: "macOS stretches it to fit your screen, which looks softer."
		}
	}

	static let announcements = "Announcements"

	static let canaryFeatures = "Canary Features"

	static func contactPublisherTitle(region: GameRegion) -> String {
		if region.publisher == .gryphline {
			return "Contact Gryphline…"
		}
		if region.publisher == .hypergryph {
			return "Contact Hypergryph…"
		}
		return "Contact Yostar…"
	}
	static func gameAccountIssuesDetail(region: GameRegion) -> String {
		if region.publisher == .gryphline {
			return "Contact Gryphline for account, payment, or game-service problems."
		}
		if region.publisher == .hypergryph {
			return "Contact Hypergryph for account, payment, or game-service problems."
		}
		return "Contact Yostar for account, payment, or game-service problems."
	}

	/// Tells players which in-game resolution produces the launcher's window size.
	static func inGameResolutionNote(window: GameDisplaySize, pixelsPerPoint: Int) -> String {
		"Resolutions inside Arknights count the pixels the game draws. With the sharpest picture, "
			+ "choose \(window.scaled(by: pixelsPerPoint).displayName) in the game for a "
			+ "\(window.displayName) window."
	}
}
