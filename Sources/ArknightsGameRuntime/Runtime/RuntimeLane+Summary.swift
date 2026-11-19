// SPDX-License-Identifier: MPL-2.0

import ArknightsCore

extension RuntimeLane {
	/// One sentence that says what the lane does. The setup step and Settings both show it.
	package var summary: String {
		switch self {
		case .arm: "Runs natively on Apple silicon."
		case .x86: "Runs through Rosetta 2. Use it on macOS 15 or as a fallback."
		}
	}
}
