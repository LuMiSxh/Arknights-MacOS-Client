// SPDX-License-Identifier: MPL-2.0

import AppKit

/// The screen the display choices are sized for: usable area in points and the panel's full
/// pixel size.
package struct GameScreenMetrics: Equatable, Sendable {
	package let visibleSize: CGSize
	package let pixelSize: CGSize
	/// Height of a standard window title bar, which a windowed game's content area gives up.
	package var titleBarHeight = AppConstants.Game.standardWindowTitleBarHeight

	init(
		visibleSize: CGSize,
		pixelSize: CGSize,
		titleBarHeight: CGFloat = AppConstants.Game.standardWindowTitleBarHeight
	) {
		self.visibleSize = visibleSize
		self.pixelSize = pixelSize
		self.titleBarHeight = titleBarHeight
	}

	@MainActor package static var main: GameScreenMetrics? {
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
	package var fullscreenResolution: GameDisplaySize {
		GameDisplaySize.largestOfficial(
			fitting: GameDisplaySize(width: Int(pixelSize.width), height: Int(pixelSize.height)))
			?? .fullHD
	}
}

/// How big a windowed game should be.
package enum GameWindowSizeChoice: CaseIterable, Sendable {
	/// The screen's usable area minus the window title bar, like a zoomed window.
	case fillScreen
	/// The largest 16:9 preset within `AppConstants.Game.compactWindowScreenShare` of the screen.
	case leaveRoom

	package func size(on screen: GameScreenMetrics) -> GameDisplaySize {
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
	package static func matching(_ size: GameDisplaySize, on screen: GameScreenMetrics) -> Self? {
		allCases.first { $0.size(on: screen) == size }
	}
}

extension Int {
	fileprivate func clamped(to range: ClosedRange<Int>) -> Int {
		Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
	}
}
