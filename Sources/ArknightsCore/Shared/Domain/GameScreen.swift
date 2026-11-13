// SPDX-License-Identifier: MPL-2.0

import AppKit

/// Identifies a display across launches and reconnects. `uuid` is the CGDisplay UUID. `name` is
/// the localized name that Settings shows.
package struct GameDisplayIdentity: Codable, Hashable, Sendable {
	package let uuid: String
	package let name: String
}

/// One connected display, as AppKit reports it.
package struct GameScreenInfo: Equatable, Sendable {
	/// The CoreGraphics ID. It can change on reconnect, so a saved choice stores `identity`.
	let displayID: CGDirectDisplayID
	package let identity: GameDisplayIdentity
	/// Frame and visible frame in points. The visible frame excludes the menu bar and the Dock.
	let frameSize: CGSize
	let visibleSize: CGSize
	package let backingScaleFactor: CGFloat
	/// Points the notch covers at the top of the display; zero without a notch.
	let notchHeight: CGFloat
}

/// The connected displays and the order Wine lists them in. Tests build one directly. Only
/// `system()` reads AppKit.
package struct GameScreenList: Equatable, Sendable {
	/// The screens in `NSScreen.screens` order. The first screen is the primary display.
	package let screens: [GameScreenInfo]
	/// Every online display in `CGGetOnlineDisplayList` order, with the display it mirrors.
	let onlineDisplays: [OnlineDisplay]
	let titleBarHeight: CGFloat

	struct OnlineDisplay: Equatable, Sendable {
		let id: CGDirectDisplayID
		/// Zero when the display mirrors nothing.
		let mirrorOf: CGDirectDisplayID
	}

	private static let onlineDisplayCapacity = 32
	// AppKit has no typed key for the CoreGraphics ID of a screen.
	private static let screenNumberKey = NSDeviceDescriptionKey(rawValue: "NSScreenNumber")

	/// The screen the game opens on. A saved display that is not connected resolves to the primary
	/// display and sets `isFallback`.
	package func resolve(_ choice: GameDisplayIdentity?) -> GameScreenResolution? {
		guard let primary = screens.first else { return nil }
		let chosen = choice.flatMap { saved in screens.first { $0.identity.uuid == saved.uuid } }
		let screen = chosen ?? primary
		guard let monitorIndex = wineMonitorIndex(of: screen.displayID) else { return nil }
		return GameScreenResolution(
			screen: screen,
			titleBarHeight: titleBarHeight,
			isFallback: choice != nil && chosen == nil,
			isPrimary: screen.displayID == primary.displayID,
			monitorIndex: monitorIndex)
	}

	/// The 1-based `-monitor` value Wine gives `displayID`, or nil when Wine does not list it.
	func wineMonitorIndex(of displayID: CGDirectDisplayID) -> Int? {
		wineMonitorOrder().firstIndex(of: displayID).map { $0 + 1 }
	}

	/// Unity's `-monitor` counts the monitors Wine's winemac driver lists, not `NSScreen.screens`.
	/// `macdrv_get_monitors` in `cocoa_display.m` walks `CGGetOnlineDisplayList` order, keeps each
	/// display that shows or mirrors a screen, then swaps the primary screen's entry to the front.
	func wineMonitorOrder() -> [CGDirectDisplayID] {
		guard let primary = screens.first?.displayID else { return [] }
		var entries: [(display: CGDirectDisplayID, screen: CGDirectDisplayID)] = []
		for display in onlineDisplays {
			guard
				let screen = screens.first(where: {
					$0.displayID == display.id || $0.displayID == display.mirrorOf
				})
			else { continue }
			entries.append((display.id, screen.displayID))
		}
		// Wine keeps the last entry for the primary screen as its primary index.
		if let index = entries.lastIndex(where: { $0.screen == primary }), index > 0 {
			entries.swapAt(0, index)
		}
		return entries.map(\.display)
	}

	/// Reads the connected displays. Call it on the main actor.
	@MainActor package static func system() -> GameScreenList {
		let screens = NSScreen.screens.compactMap { screen -> GameScreenInfo? in
			guard
				let number = screen.deviceDescription[screenNumberKey] as? NSNumber
			else { return nil }
			let displayID = CGDirectDisplayID(number.uint32Value)
			guard let uuid = uuidString(for: displayID) else { return nil }
			return GameScreenInfo(
				displayID: displayID,
				identity: GameDisplayIdentity(uuid: uuid, name: screen.localizedName),
				frameSize: screen.frame.size,
				visibleSize: screen.visibleFrame.size,
				backingScaleFactor: screen.backingScaleFactor,
				notchHeight: screen.safeAreaInsets.top)
		}
		var displayIDs = [CGDirectDisplayID](repeating: 0, count: onlineDisplayCapacity)
		var count: UInt32 = 0
		var online: [OnlineDisplay] = []
		if CGGetOnlineDisplayList(UInt32(displayIDs.count), &displayIDs, &count) == .success {
			online = displayIDs.prefix(Int(count)).map {
				OnlineDisplay(id: $0, mirrorOf: CGDisplayMirrorsDisplay($0))
			}
		}
		let content = NSRect(x: 0, y: 0, width: 100, height: 100)
		let frame = NSWindow.frameRect(forContentRect: content, styleMask: [.titled])
		return GameScreenList(
			screens: screens, onlineDisplays: online, titleBarHeight: frame.height - content.height)
	}

	/// The CGDisplay UUID as text. It stays the same across launches and reconnects.
	private static func uuidString(for displayID: CGDirectDisplayID) -> String? {
		guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
			return nil
		}
		return CFUUIDCreateString(nil, uuid) as String?
	}
}

/// The screen the game opens on. It is resolved once per launch and sets the window size, the
/// fullscreen size, the Retina scale, and the settings preview.
package struct GameScreenResolution: Equatable, Sendable {
	package let screen: GameScreenInfo
	let titleBarHeight: CGFloat
	/// True when the saved display is not connected, so the primary display stands in for it.
	package let isFallback: Bool
	package let isPrimary: Bool
	/// The 1-based `-monitor` value Wine gives the screen.
	let monitorIndex: Int

	package var metrics: GameScreenMetrics {
		GameScreenMetrics(screen: screen, titleBarHeight: titleBarHeight)
	}

	package var fullscreenDisplay: GameFullscreenDisplay { GameFullscreenDisplay(screen: screen) }

	/// The `-monitor` value for a launch. Fullscreen always names its display. A windowed launch
	/// names its display only when that display is not the primary one.
	package func monitorArgument(fullscreen: Bool) -> Int? {
		guard fullscreen || !isPrimary else { return nil }
		return monitorIndex
	}
}
