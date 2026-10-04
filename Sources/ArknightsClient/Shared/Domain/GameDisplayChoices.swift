// SPDX-License-Identifier: MPL-2.0

import AppKit

/// The screen the display choices are sized for: usable area in points and the panel's full
/// pixel size.
struct GameScreenMetrics: Equatable, Sendable {
	let visibleSize: CGSize
	let pixelSize: CGSize
	/// Height of a standard window title bar, which a windowed game's content area gives up.
	var titleBarHeight = AppConstants.Game.standardWindowTitleBarHeight

	@MainActor static var main: GameScreenMetrics? {
		guard let screen = NSScreen.main else { return nil }
		let content = NSRect(x: 0, y: 0, width: 100, height: 100)
		let frame = NSWindow.frameRect(forContentRect: content, styleMask: [.titled])
		return GameScreenMetrics(
			visibleSize: screen.visibleFrame.size,
			pixelSize: CGSize(
				width: screen.frame.width * screen.backingScaleFactor,
				height: screen.frame.height * screen.backingScaleFactor
			),
			titleBarHeight: frame.height - content.height
		)
	}

	/// The official game resolution with the most pixels that the panel can show unscaled.
	var fullscreenResolution: GameResolution {
		GameResolution.largest(
			fitting: GameDisplaySize(width: Int(pixelSize.width), height: Int(pixelSize.height)))
			?? .fullHD
	}
}

/// How big a windowed game should be, in plain terms.
enum GameWindowSizeChoice: CaseIterable, Sendable {
	/// The screen's usable area minus the window title bar, like a zoomed window.
	case fillScreen
	/// The largest 16:9 preset within `AppConstants.Game.compactWindowScreenShare` of the screen.
	case leaveRoom

	func size(on screen: GameScreenMetrics) -> GameDisplaySize {
		switch self {
		case .fillScreen:
			let range = GameDisplaySize.validDimensions
			return GameDisplaySize(
				width: Int(screen.visibleSize.width.rounded(.down)).clamped(to: range),
				height: Int((screen.visibleSize.height - screen.titleBarHeight).rounded(.down))
					.clamped(to: range)
			)
		case .leaveRoom:
			let share = AppConstants.Game.compactWindowScreenShare
			let widescreen = GameDisplaySize.windowPresets.filter { $0.width * 9 == $0.height * 16 }
			return widescreen.last {
				CGFloat($0.width) <= screen.visibleSize.width * share
					&& CGFloat($0.height) <= screen.visibleSize.height * share
			} ?? widescreen[0]
		}
	}

	/// The choice whose size equals `size` on this screen, or nil for a custom size.
	static func matching(_ size: GameDisplaySize, on screen: GameScreenMetrics) -> Self? {
		allCases.first { $0.size(on: screen) == size }
	}
}

/// How much detail fullscreen draws, in plain terms.
enum GameFullscreenDetail: CaseIterable, Sendable {
	/// The display's own size.
	case full
	/// The largest choice no taller than `AppConstants.Game.balancedFullscreenHeight`.
	case balanced
	/// Full HD.
	case lighter

	func resolution(native: GameDisplaySize?) -> GameFullscreenResolution {
		switch self {
		case .full:
			.native
		case .balanced:
			GameFullscreenResolution.choices(native: native)
				.compactMap { choice -> GameDisplaySize? in
					guard case .fixed(let size) = choice,
						size.height <= AppConstants.Game.balancedFullscreenHeight
					else { return nil }
					return size
				}
				.max { $0.pixelCount < $1.pixelCount }
				.map(GameFullscreenResolution.fixed) ?? .native
		case .lighter:
			.fixed(GameDisplaySize(.fullHD))
		}
	}

	/// The detail level that draws `resolution` on this display, or nil for a custom size.
	static func matching(_ resolution: GameFullscreenResolution, native: GameDisplaySize?) -> Self?
	{
		available(native: native).first { $0.resolution(native: native) == resolution }
	}

	/// Levels that differ on this display. `balanced` is dropped when it draws what `full` or
	/// `lighter` draws, and `lighter` when it equals `full` or is larger than the display.
	static func available(native: GameDisplaySize?) -> [Self] {
		let full = GameFullscreenResolution.native.drawnSize(native: native)
		let lighter = GameDisplaySize(.fullHD)
		let balanced = Self.balanced.resolution(native: native).drawnSize(native: native)
		var levels = [Self.full]
		if balanced != full && balanced != lighter { levels.append(.balanced) }
		if lighter != full, native.map(lighter.fits(in:)) ?? true { levels.append(.lighter) }
		return levels
	}
}

extension GameFullscreenResolution {
	/// The size the game draws, with `.native` standing for the display's own size.
	fileprivate func drawnSize(native: GameDisplaySize?) -> GameDisplaySize? {
		switch self {
		case .native: native
		case .fixed(let size): size
		}
	}
}

extension Int {
	fileprivate func clamped(to range: ClosedRange<Int>) -> Int {
		Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
	}
}
