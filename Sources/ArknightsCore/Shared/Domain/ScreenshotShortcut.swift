// SPDX-License-Identifier: MPL-2.0

import ArknightsInfrastructure

/// The global keyboard shortcut that takes a screenshot of the running game.
package enum ScreenshotShortcut: Hashable, Sendable {
	case off
	/// Control-Option-S.
	case standard
	/// A combination the user recorded. `label` is the key's name, saved when it was recorded
	/// so that the menu does not depend on the keyboard layout at display time.
	case custom(HotKeyCombination, label: String)

	/// The key combination to register, or `nil` when the shortcut is off.
	package var hotKey: HotKeyCombination? {
		switch self {
		case .off: nil
		case .standard:
			HotKeyCombination(keyCode: HotKeyCombination.keyCodeS, modifiers: [.control, .option])
		case .custom(let combination, _): combination
		}
	}

	/// The shortcut as shown in menus, such as "⌃⌥S".
	package var displayName: String {
		switch self {
		case .off: "Off"
		case .standard: Self.modifierSymbols([.control, .option]) + "S"
		case .custom(let combination, let label):
			Self.modifierSymbols(combination.modifiers) + label
		}
	}

	/// The text saved in the preferences. The format is `custom:<keyCode>:<modifiers>:<label>`.
	package var storageValue: String {
		switch self {
		case .off: "off"
		case .standard: "standard"
		case .custom(let combination, let label):
			"custom:\(combination.keyCode):\(combination.modifiers.rawValue):\(label)"
		}
	}

	/// Reads a saved value. Returns `nil` for an unknown or malformed value.
	package init?(storageValue: String) {
		switch storageValue {
		case "off": self = .off
		case "standard": self = .standard
		default:
			// The label may contain ":", so only the first three separators split the value.
			let parts = storageValue.split(
				separator: ":", maxSplits: 3, omittingEmptySubsequences: false)
			guard parts.count == 4, parts[0] == "custom", let keyCode = UInt32(parts[1]),
				let modifiers = UInt32(parts[2]), !parts[3].isEmpty
			else { return nil }
			self = .custom(
				HotKeyCombination(keyCode: keyCode, modifiers: .init(rawValue: modifiers)),
				label: String(parts[3]))
		}
	}

	private static func modifierSymbols(_ modifiers: HotKeyCombination.Modifiers) -> String {
		var symbols = ""
		if modifiers.contains(.control) { symbols += "⌃" }
		if modifiers.contains(.option) { symbols += "⌥" }
		if modifiers.contains(.shift) { symbols += "⇧" }
		if modifiers.contains(.command) { symbols += "⌘" }
		return symbols
	}
}
