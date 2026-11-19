// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The architecture of a managed Wine runtime. Each lane has its own Wine prefix and its own
/// installed runtime, so switching lanes never changes the other lane's game environment.
package enum RuntimeLane: String, CaseIterable, Codable, Hashable, Sendable {
	case x86
	case arm

	/// The Wine prefix directory name for this lane.
	var prefixDirectoryName: String {
		switch self {
		case .x86: "Prefix"
		case .arm: "Prefix-ARM64"
		}
	}

	package var label: String {
		switch self {
		case .x86: "x86_64 via Rosetta"
		case .arm: "ARM64 native"
		}
	}
}
