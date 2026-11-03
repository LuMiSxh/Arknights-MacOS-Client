// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import CoreGraphics
import Foundation

/// A window as seen by either the window list (readiness) or ScreenCaptureKit (capture).
struct GameWindowCandidate: Equatable, Sendable {
	var windowID: CGWindowID
	var ownerProcessIdentifier: Int32
	var layer: Int
	var isOnScreen: Bool
	var alpha: Double
	var width: Double
	var height: Double

	var area: Double { width * height }

	/// Reads one entry of `CGWindowListCopyWindowInfo`. Returns nil when it lacks an owner or bounds.
	init?(windowInfo: [String: Any]) {
		guard
			let owner = (windowInfo[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
			let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any]
		else { return nil }
		windowID = (windowInfo[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0
		ownerProcessIdentifier = owner
		layer = (windowInfo[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1
		isOnScreen = (windowInfo[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
		alpha = (windowInfo[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0
		width = (bounds["Width"] as? NSNumber)?.doubleValue ?? 0
		height = (bounds["Height"] as? NSNumber)?.doubleValue ?? 0
	}

	init(
		windowID: CGWindowID, ownerProcessIdentifier: Int32, layer: Int = 0,
		isOnScreen: Bool = true,
		alpha: Double = 1, width: Double, height: Double
	) {
		self.windowID = windowID
		self.ownerProcessIdentifier = ownerProcessIdentifier
		self.layer = layer
		self.isOnScreen = isOnScreen
		self.alpha = alpha
		self.width = width
		self.height = height
	}
}

/// Decides which window is the game window. Never looks at titles.
enum GameWindowLocator {
	/// The largest window of `processIdentifier` that is a normal, visible, game-sized window.
	/// Smaller windows are helpers such as the sign-in or Notices pane.
	static func select(
		_ candidates: [GameWindowCandidate], pid processIdentifier: Int32
	)
		-> GameWindowCandidate?
	{
		candidates.filter { isGameWindow($0, pid: processIdentifier) }.max { $0.area < $1.area }
	}

	/// The largest normal window of the process, whatever its size. Used when no window passes
	/// `select`, because the launch process does not always own a game-sized window.
	static func selectFallback(
		_ candidates: [GameWindowCandidate], pid processIdentifier: Int32
	)
		-> GameWindowCandidate?
	{
		candidates.filter {
			$0.ownerProcessIdentifier == processIdentifier && $0.layer == 0 && $0.isOnScreen
				&& $0.area > 0
		}.max { $0.area < $1.area }
	}

	private static func isGameWindow(_ window: GameWindowCandidate, pid: Int32) -> Bool {
		window.ownerProcessIdentifier == pid && window.layer == 0 && window.isOnScreen
			&& window.alpha > 0 && window.width >= AppConstants.Game.minimumGameWindowWidth
			&& window.height >= AppConstants.Game.minimumGameWindowHeight
	}
}
