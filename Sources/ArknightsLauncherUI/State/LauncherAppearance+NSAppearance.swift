// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore

extension LauncherAppearance {
	/// nil follows the system; the named appearances pin the whole app, including native controls.
	package var nsAppearance: NSAppearance? {
		switch self {
		case .system: nil
		case .light: NSAppearance(named: .aqua)
		case .dark: NSAppearance(named: .darkAqua)
		}
	}
}
