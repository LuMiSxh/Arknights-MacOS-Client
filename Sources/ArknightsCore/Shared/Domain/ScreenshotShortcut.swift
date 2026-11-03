// SPDX-License-Identifier: MPL-2.0

import ArknightsInfrastructure

/// The global keyboard shortcut that takes a screenshot of the running game.
package enum ScreenshotShortcut: String, CaseIterable, Sendable {
	case off
	case controlOptionS
	case f13
	case controlOptionCommandS

	/// The key combination to register, or `nil` when the shortcut is off.
	package var hotKey: HotKeyCombination? {
		switch self {
		case .off: nil
		case .controlOptionS:
			HotKeyCombination(keyCode: HotKeyCombination.keyCodeS, modifiers: [.control, .option])
		case .f13: HotKeyCombination(keyCode: HotKeyCombination.keyCodeF13)
		case .controlOptionCommandS:
			HotKeyCombination(
				keyCode: HotKeyCombination.keyCodeS, modifiers: [.control, .option, .command])
		}
	}
}
